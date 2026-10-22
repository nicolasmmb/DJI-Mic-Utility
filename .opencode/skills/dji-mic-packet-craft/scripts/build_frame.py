#!/usr/bin/env python3
"""Self-contained DJI Mic DUML frame builder/parser.

Examples:
  python3 build_frame.py --target 0 --command 0x39 --value 6 --sequence 0x1234
  python3 build_frame.py --verify "55 16 04 fc 02 5a 34 12 40 5b 01 02 00 00 00 00 39 00 01 06 ..."

No project imports. Standard library only.
"""

from __future__ import annotations

import argparse

SOF = 0x55
LENGTH = 22
VERSION = 0x04


def crc8(data: bytes | bytearray) -> int:
    value = 0x77
    for byte in data:
        value ^= byte
        for _ in range(8):
            value = (value >> 1) ^ (0x8C if value & 1 else 0)
    return value


def crc16(data: bytes | bytearray) -> int:
    value = 0x3692
    for byte in data:
        value ^= byte
        for _ in range(8):
            value = (value >> 1) ^ (0x8408 if value & 1 else 0)
    return value


def build(target: int, command: int, value: int, sequence: int) -> bytes:
    packet = bytearray(LENGTH)
    packet[0] = SOF
    packet[1] = LENGTH
    packet[2] = VERSION
    packet[3] = crc8(packet[0:3])
    packet[4] = 0x02
    packet[5] = 0x5A
    packet[6] = sequence & 0xFF
    packet[7] = (sequence >> 8) & 0xFF
    packet[8] = 0x40
    packet[9] = 0x5B
    packet[10] = 0x01
    packet[11] = 0x02
    packet[12] = target & 0xFF
    packet[13] = (target >> 8) & 0xFF
    packet[16] = command & 0xFF
    packet[17] = (command >> 8) & 0xFF
    packet[18] = 0x01
    packet[19] = value & 0xFF
    checksum = crc16(packet[0:20])
    packet[20] = checksum & 0xFF
    packet[21] = (checksum >> 8) & 0xFF
    return bytes(packet)


def parse(packet: bytes) -> dict:
    if len(packet) < 13:
        raise ValueError("packet too short")
    if packet[0] != SOF:
        raise ValueError("missing start-of-frame 0x55")

    declared = int.from_bytes(packet[1:3], "little") & 0x3FF
    version = packet[2]
    expected_crc8 = crc8(packet[0:3])
    expected_crc16 = crc16(packet[:-2])
    actual_crc16 = int.from_bytes(packet[-2:], "little")

    info = {
        "length": len(packet),
        "declared_length": declared,
        "version": version,
        "crc8_ok": expected_crc8 == packet[3],
        "crc16_ok": expected_crc16 == actual_crc16,
        "crc8": f"0x{packet[3]:02x}",
        "crc16": f"0x{actual_crc16:04x}",
        "sequence": int.from_bytes(packet[6:8], "little"),
    }

    if packet[8] & 0x80:
        info["kind"] = "ACK"
        info["ack_value"] = packet[11] if len(packet) > 12 else None
        info["accepted"] = info["ack_value"] == 0
        return info

    payload = packet[11:-2]
    if packet[9] == 0x5B and packet[10] == 0x03:
        info["kind"] = "PUSH"
        info["push_type"] = payload[3] if len(payload) > 3 else None
        info["payload_hex"] = payload.hex(" ")
        return info

    info["kind"] = "COMMAND"
    if len(payload) >= 7:
        info["target"] = int.from_bytes(payload[1:3], "little")
        info["command"] = int.from_bytes(payload[5:7], "little")
        info["value"] = payload[8] if len(payload) > 8 else None
    return info


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target", type=lambda value: int(value, 0), default=0)
    parser.add_argument("--command", type=lambda value: int(value, 0), required=False)
    parser.add_argument("--value", type=lambda value: int(value, 0), default=0)
    parser.add_argument("--sequence", type=lambda value: int(value, 0), default=1)
    parser.add_argument("--verify", help="hex bytes to verify/parse")
    args = parser.parse_args()

    if args.verify:
        packet = bytes.fromhex(args.verify.replace(",", " ").replace("0x", ""))
        for key, value in parse(packet).items():
            print(f"{key}: {value}")
        return

    if args.command is None:
        parser.error("--command is required unless --verify is used")

    packet = build(args.target, args.command, args.value, args.sequence)
    print(packet.hex(" "))
    for key, value in parse(packet).items():
        print(f"{key}: {value}")


if __name__ == "__main__":
    main()
