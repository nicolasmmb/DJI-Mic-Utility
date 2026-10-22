"""DJI Wireless Mic RX protocol: framing, CRCs, packet parsing.

This module is an independent implementation built from protocol notes in
docs/protocol-notes.md. It does not vendor or import any third-party DJI
project.
"""

from __future__ import annotations

import struct
from dataclasses import dataclass, field
from typing import Iterable

# ---------------------------------------------------------------------------
# USB identity
# ---------------------------------------------------------------------------

VENDOR_ID = 0x2CA3
PRODUCT_ID = 0x4011

# The configuration/control channel exposed by the receiver. Interface 0 is
# HID and is not used here.
CONTROL_INTERFACE = 6
EP_OUT = 0x06
EP_IN = 0x86

# ---------------------------------------------------------------------------
# DUML framing
# ---------------------------------------------------------------------------

SOF = 0x55
PROTOCOL_VERSION = 0x04
PACKET_LENGTH = 22

CRC8_INIT = 0x77
CRC8_POLY = 0x31
CRC16_INIT = 0x3692
CRC16_POLY = 0x8408


def _make_tables() -> tuple[tuple[int, ...], tuple[int, ...]]:
    crc8 = [0] * 256
    crc16 = [0] * 256
    for value in range(256):
        c = value
        k = value
        for _ in range(8):
            c = (c >> 1) ^ (-(c & 1) & 0x8C)
            k = (k >> 1) ^ (-(k & 1) & CRC16_POLY)
        crc8[value] = c
        crc16[value] = k
    return tuple(crc8), tuple(crc16)


_CRC8_TABLE, _CRC16_TABLE = _make_tables()


def crc8(data: bytes) -> int:
    value = CRC8_INIT
    for byte in data:
        value = _CRC8_TABLE[value ^ byte]
    return value


def crc16(data: bytes) -> int:
    value = CRC16_INIT
    for byte in data:
        value = (value >> 8) ^ _CRC16_TABLE[(value ^ byte) & 0xFF]
    return value


def packet_length(packet: bytes) -> int:
    return int.from_bytes(packet[1:3], "little") & 0x3FF


def packet_version(packet: bytes) -> int:
    return (int.from_bytes(packet[1:3], "little") >> 10) & 0x3F


def build_command(target: int, command: int, value: int, sequence: int) -> bytes:
    """Build a 22-byte v2 command packet."""
    packet = bytearray(PACKET_LENGTH)
    packet[0] = SOF
    packet[1] = PACKET_LENGTH
    packet[2] = PROTOCOL_VERSION
    packet[3] = crc8(packet[0:3])
    packet[4] = 0x02
    packet[5] = 0x5A
    struct.pack_into("<H", packet, 6, sequence & 0xFFFF)
    packet[8] = 0x40  # acknowledgement requested
    packet[9] = 0x5B
    packet[10] = 0x01
    packet[11] = 0x02  # addressed command
    struct.pack_into("<H", packet, 12, target & 0xFFFF)
    struct.pack_into("<H", packet, 14, 0)
    struct.pack_into("<H", packet, 16, command & 0xFFFF)
    packet[18] = 0x01  # payload length
    packet[19] = value & 0xFF
    struct.pack_into("<H", packet, 20, crc16(packet[0:20]))
    return bytes(packet)


class StreamParser:
    """Incremental parser for a byte stream that may contain partial frames."""

    def __init__(self) -> None:
        self._buffer = bytearray()

    def feed(self, data: bytes) -> list[bytes]:
        self._buffer.extend(data)
        frames: list[bytes] = []

        while True:
            offset = self._buffer.find(SOF)
            if offset < 0:
                self._buffer.clear()
                break
            if offset:
                del self._buffer[:offset]

            if len(self._buffer) < 4:
                break

            if crc8(bytes(self._buffer[0:3])) != self._buffer[3]:
                del self._buffer[0]
                continue

            length = packet_length(self._buffer)
            if length < 13 or length > 2048:
                del self._buffer[0]
                continue
            if len(self._buffer) < length:
                break

            candidate = bytes(self._buffer[:length])
            expected = int.from_bytes(candidate[-2:], "little")
            if crc16(candidate[:-2]) != expected:
                del self._buffer[0]
                continue

            del self._buffer[:length]
            frames.append(candidate)

        return frames


# ---------------------------------------------------------------------------
# Packet decoding
# ---------------------------------------------------------------------------

ADDRESS_RX = 0x0000
ADDRESS_TX1 = 0x0001
ADDRESS_TX2 = 0x0002
ADDRESS_ALL_TX = 0xFFFF

PUSH_COMMAND_SET = 0x5B
PUSH_HEARTBEAT = 0x03

PUSH_IDENTITY = 0x01
PUSH_STATUS = 0x03
PUSH_LEVEL = 0x05

TX_UNITS = {0x01: 1, 0x02: 2, 0x04: 3, 0x08: 4}


@dataclass
class Push:
    kind: str
    payload: bytes
    rx: dict = field(default_factory=dict)
    tx: dict[int, dict] = field(default_factory=dict)


def _i8(data: bytes, offset: int) -> int:
    return struct.unpack_from("<b", data, offset)[0]


def _u8(data: bytes, offset: int) -> int:
    return data[offset]


def _ascii(data: bytes, offset: int, size: int) -> str:
    chunk = data[offset : offset + size]
    return chunk.decode("ascii", errors="replace").rstrip("\x00 ")


def _vstring(data: bytes, offset: int) -> str:
    if offset <= 0 or offset > len(data):
        return ""
    size = data[offset - 1]
    if size == 0 or offset + size > len(data):
        return ""
    return _ascii(data, offset, size)


def _version(data: bytes, offset: int) -> str:
    if offset + 4 > len(data):
        return ""
    return ".".join(f"{byte:02d}" for byte in reversed(data[offset : offset + 4]))


def parse_frame(packet: bytes) -> dict | None:
    """Decode one validated frame into a plain dictionary."""
    if len(packet) < 13 or packet[0] != SOF:
        return None

    sequence = int.from_bytes(packet[6:8], "little")
    header = {
        "sequence": sequence,
        "source": packet[4],
        "destination": packet[5],
        "flags": packet[8],
        "command_set": packet[9],
        "command_id": packet[10],
        "length": len(packet),
    }

    if packet[8] & 0x80:
        header["kind"] = "ack"
        # The single ack byte tells whether the device accepted the command:
        # 0x00 accepted, 0xff rejected.
        header["ack_value"] = packet[11] if len(packet) > 12 else None
        header["accepted"] = header["ack_value"] == 0x00
        return header

    payload = packet[11:-2]
    if packet[9] == PUSH_COMMAND_SET and packet[10] == PUSH_HEARTBEAT:
        push = parse_push(payload)
        if push is None:
            return None
        header["kind"] = "push"
        header["push"] = push
        return header

    header["kind"] = "command"
    header["payload"] = payload
    if len(payload) >= 5:
        header["target"] = int.from_bytes(payload[1:3], "little")
        header["target_command"] = int.from_bytes(payload[5:7], "little")
    return header


def parse_push(payload: bytes) -> Push | None:
    if len(payload) < 4:
        return None

    kind = payload[3]
    if kind == PUSH_IDENTITY:
        return _parse_identity(payload)
    if kind == PUSH_STATUS:
        return _parse_status(payload)
    if kind == PUSH_LEVEL:
        return _parse_level(payload)
    return Push(kind=f"unknown-0x{kind:02x}", payload=payload)


def _parse_identity(payload: bytes) -> Push:
    push = Push(kind="identity", payload=payload)

    if len(payload) >= 46:
        push.rx = {
            "product_name": _vstring(payload, 45),
            "serial": _ascii(payload, 13, 14),
            "firmware": _version(payload, 9),
            "address_suffix": _ascii(payload, 33, 6),
        }

        offset = 45 + payload[44]
        while offset + 42 <= len(payload):
            unit = TX_UNITS.get(payload[offset + 1])
            if payload[offset] != 0x01 or unit is None:
                break
            push.tx[unit] = {
                "product_name": _vstring(payload, offset + 42),
                "serial": _ascii(payload, offset + 10, 14),
                "firmware": _version(payload, offset + 6),
                "address_suffix": _ascii(payload, offset + 30, 6),
            }
            offset += 42 + payload[offset + 41]

    return push


def _parse_status(payload: bytes) -> Push:
    push = Push(kind="status", payload=payload)

    if len(payload) >= 38:
        push.rx = {
            # On the Mic Mini 2 receiver the noise-cancellation switch state
            # lives in payload byte 9, not in the per-TX slot.
            "noise_cancel": bool(payload[9] & 0x20),
            "noise_cancel_strong": bool(payload[9] & 0x08),
            "stereo": bool(payload[10] & 0x04),
            "safety_track": bool(payload[37] & 0x40),
            "gain": _i8(payload, 11),
            "monitoring_gain": _i8(payload, 16),
            "clipping_control": bool(payload[37] & 0x10),
            "auto_off": bool(payload[10] & 0x01),
            # Keep the raw bytes so new fields can be correlated later.
            "flags9": payload[9],
            "flags10": payload[10],
            "flags37": payload[37],
        }

    # TX slots start after the 41-byte status header; each is 32 bytes.
    for offset in range(41, len(payload) - 31, 32):
        if payload[offset] != 0x02:
            continue
        unit = TX_UNITS.get(payload[offset + 1])
        if unit is None:
            continue
        tone_bits = payload[offset + 9] & 0xC0
        tone = "rich" if tone_bits == 0x40 else "bright" if tone_bits == 0x80 else "regular"
        gauge = (payload[offset + 7] >> 2) & 0x07
        push.tx[unit] = {
            "noise_cancel": bool(payload[offset + 7] & 0x01),
            "noise_cancel_strong": bool(payload[offset + 6] & 0x20),
            "noise_cancel_via_button": bool(payload[offset + 6] & 0x80),
            "low_cut": bool(payload[offset + 9] & 0x20),
            "leds_off": bool(payload[offset + 6] & 0x02),
            "auto_off": bool(payload[offset + 6] & 0x10),
            "auto_off_timer_active": bool(payload[offset + 6] & 0x08),
            "clipping_control": bool(payload[offset + 8] & 0x04),
            "voice_tone": tone,
            "charging": bool(payload[offset + 7] & 0x02),
            # 1 = full, 7 = empty; 0 is believed unreachable.
            "battery_gauge": gauge,
            "battery_full": gauge == 1,
            "battery_low": gauge >= 6,
        }

    return push


def _parse_level(payload: bytes) -> Push:
    push = Push(kind="level", payload=payload)
    for offset in range(3, len(payload) - 6, 7):
        if payload[offset] != 0x05:
            continue
        unit = TX_UNITS.get(payload[offset + 1])
        if unit is None:
            continue
        push.tx[unit] = {"input_level": _u8(payload, offset + 6)}
    return push


def summarize(packet: bytes) -> str:
    """One-line human-readable summary used by the CLI."""
    info = parse_frame(packet)
    if info is None:
        return f"invalid frame ({len(packet)} bytes): {packet.hex(' ')}"

    if info["kind"] == "ack":
        result = "ok" if info.get("accepted") else f"rejected(0x{info.get('ack_value', 0):02x})"
        return f"ACK seq={info['sequence']:04x} {result}"

    if info["kind"] == "push":
        push: Push = info["push"]
        if push.kind == "status":
            rx = push.rx
            parts = [
                f"Status seq={info['sequence']:04x}",
                f"nc={rx.get('noise_cancel')}/{rx.get('noise_cancel_strong')}",
                f"gain={rx.get('gain')}dB",
                f"monitor={rx.get('monitoring_gain')}dB",
                f"stereo={rx.get('stereo')}",
                f"safety={rx.get('safety_track')}",
            ]
            for unit, tx in sorted(push.tx.items()):
                parts.append(
                    f"TX{unit}[nc={tx.get('noise_cancel')}/{tx.get('voice_tone')},"
                    f"strong={tx.get('noise_cancel_strong')},"
                    f"lowcut={tx.get('low_cut')},leds_off={tx.get('leds_off')},"
                    f"auto_off={tx.get('auto_off')},level={tx.get('input_level', '-')},"
                    f"bat={tx.get('battery_gauge')}]"
                )
            return " ".join(parts)

        if push.kind == "identity":
            rx = push.rx
            parts = [
                f"Identity seq={info['sequence']:04x}",
                f"RX={rx.get('product_name')!r}",
                f"fw={rx.get('firmware')}",
                f"serial={rx.get('serial')}",
            ]
            for unit, tx in sorted(push.tx.items()):
                parts.append(
                    f"TX{unit}={tx.get('product_name')!r} fw={tx.get('firmware')} "
                    f"serial={tx.get('serial')}"
                )
            return " ".join(parts)

        if push.kind == "level":
            levels = ", ".join(
                f"TX{unit}={tx.get('input_level')}" for unit, tx in sorted(push.tx.items())
            )
            return f"Level seq={info['sequence']:04x} {levels}"

        return f"Push {push.kind} seq={info['sequence']:04x} len={len(push.payload)}"

    return f"Command seq={info['sequence']:04x}"


def iter_frames(chunks: Iterable[bytes]) -> Iterable[bytes]:
    parser = StreamParser()
    for chunk in chunks:
        yield from parser.feed(chunk)
