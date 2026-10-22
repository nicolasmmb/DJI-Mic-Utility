#!/usr/bin/env python3
"""Command-line probe for the DJI Wireless Mic RX.

Examples:
    uv run python tools/poc/dji_probe.py scan
    uv run python tools/poc/dji_probe.py monitor
    uv run python tools/poc/dji_probe.py set noise-cancel strong
    uv run python tools/poc/dji_probe.py set gain 6
    uv run python tools/poc/dji_probe.py set voice-tone bright --tx 1
    uv run python tools/poc/dji_probe.py raw 551604fc025a...
"""

from __future__ import annotations

import argparse
import json
import random
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

import usb.core
import usb.util

from dji_protocol import (
    ADDRESS_ALL_TX,
    ADDRESS_RX,
    ADDRESS_TX1,
    ADDRESS_TX2,
    CONTROL_INTERFACE,
    EP_IN,
    EP_OUT,
    PRODUCT_ID,
    VENDOR_ID,
    StreamParser,
    build_command,
    crc8,
    parse_frame,
    summarize,
)


# ---------------------------------------------------------------------------
# Settings exposed by the probe
# ---------------------------------------------------------------------------

ON_OFF = {"on": 1, "off": 0, "true": 1, "false": 0, "1": 1, "0": 0}


def _on_off(value: str) -> int:
    try:
        return ON_OFF[value.lower()]
    except KeyError:
        raise argparse.ArgumentTypeError("use on/off") from None


def _db(value: str) -> int:
    number = int(value)
    if not -12 <= number <= 12:
        raise argparse.ArgumentTypeError("gain must be between -12 and 12")
    return number & 0xFF


SETTINGS = {
    "noise-cancel": {
        "command": 0x0038,
        "target": ADDRESS_ALL_TX,
        "help": "noise cancellation on/off (on/off)",
        "convert": _on_off,
    },
    "noise-cancel-mode": {
        "command": 0x0037,
        "target": ADDRESS_ALL_TX,
        "help": "noise cancellation level (basic/strong)",
        "convert": lambda value: {"basic": 0, "strong": 1}[value.lower()],
    },
    "voice-tone": {
        "command": 0x0029,
        "target": ADDRESS_TX1,
        "help": "voice tone (regular/rich/bright); use --tx 1 or 2",
        "convert": lambda value: {"regular": 0, "rich": 1, "bright": 2}[value.lower()],
    },
    "gain": {
        "command": 0x0039,
        "target": ADDRESS_RX,
        "help": "receiver gain in dB (-12, -6, 0, 6, 12)",
        "convert": _db,
    },
    "monitoring-gain": {
        "command": 0x0026,
        "target": ADDRESS_RX,
        "help": "receiver monitoring gain in dB (-12..12)",
        "convert": _db,
    },
    "safety-track": {
        "command": 0x0021,
        "target": ADDRESS_RX,
        "help": "safety track on/off",
        "convert": _on_off,
    },
    "stereo": {
        "command": 0x0008,
        "target": ADDRESS_RX,
        "help": "audio channel (mono/stereo)",
        "convert": lambda value: {"mono": 0, "stereo": 2}[value.lower()],
    },
    "low-cut": {
        "command": 0x0003,
        "target": ADDRESS_ALL_TX,
        "help": "low cut on/off",
        "convert": _on_off,
    },
    "leds": {
        "command": 0x000A,
        "target": ADDRESS_ALL_TX,
        "help": "microphone LEDs (on/off)",
        "convert": lambda value: {"on": 0, "off": 2}[value.lower()],
    },
    "mic-led": {
        "command": 0x000A,
        "target": ADDRESS_ALL_TX,
        "help": "alias for leds (on/off)",
        "convert": lambda value: {"on": 0, "off": 2}[value.lower()],
    },
    "auto-off": {
        "command": 0x0010,
        "target": ADDRESS_RX,
        "help": "receiver auto power off on/off",
        "convert": _on_off,
    },
    "auto-off-tx": {
        "command": 0x0010,
        "target": ADDRESS_ALL_TX,
        "help": "transmitter auto power off on/off (broadcast)",
        "convert": _on_off,
    },
    "clipping-control": {
        "command": 0x001E,
        "target": ADDRESS_RX,
        "help": "clipping control on/off (0x001e)",
        "convert": _on_off,
    },
    "clipping-control-alt": {
        "command": 0x0024,
        "target": ADDRESS_RX,
        "help": "experimental alias for clipping control (0x0024)",
        "convert": _on_off,
    },
    "on-with-camera": {
        "command": 0x0020,
        "target": ADDRESS_RX,
        "help": "turn receiver on with camera on/off",
        "convert": _on_off,
    },
    "nc-via-button": {
        "command": 0x000F,
        "target": ADDRESS_ALL_TX,
        "help": "allow noise cancellation via transmitter button on/off",
        "convert": _on_off,
    },
}


# ---------------------------------------------------------------------------
# USB helpers
# ---------------------------------------------------------------------------


def find_device():
    device = usb.core.find(idVendor=VENDOR_ID, idProduct=PRODUCT_ID)
    if device is None:
        raise RuntimeError(
            f"device {VENDOR_ID:04x}:{PRODUCT_ID:04x} not found; is the receiver connected?"
        )
    return device


def open_device():
    device = find_device()

    try:
        device.get_active_configuration()
    except usb.core.USBError:
        device.set_configuration()

    try:
        device.detach_kernel_driver(CONTROL_INTERFACE)
    except (NotImplementedError, usb.core.USBError):
        # macOS does not have kernel drivers to detach. On Linux this may also
        # fail when no driver is bound.
        pass

    usb.util.claim_interface(device, CONTROL_INTERFACE)
    return device


def close_device(device) -> None:
    try:
        usb.util.release_interface(device, CONTROL_INTERFACE)
    except usb.core.USBError:
        pass
    try:
        usb.util.dispose_resources(device)
    except usb.core.USBError:
        pass


def read_frames(device, parser: StreamParser, timeout_ms: int = 1000):
    try:
        chunk = device.read(EP_IN, 1024, timeout=timeout_ms)
    except usb.core.USBTimeoutError:
        return []
    return parser.feed(bytes(chunk))


def write_packet(device, packet: bytes) -> None:
    written = device.write(EP_OUT, packet, timeout=1000)
    if written != len(packet):
        raise RuntimeError(f"short write: {written}/{len(packet)} bytes")


def frame_to_dict(info: dict) -> dict:
    result = {
        "sequence": info["sequence"],
        "kind": info["kind"],
        "length": info["length"],
    }
    if info["kind"] == "ack":
        result["ack_value"] = info.get("ack_value")
        result["accepted"] = info.get("accepted")
    if info["kind"] == "push":
        push = info["push"]
        result["push"] = push.kind
        if push.rx:
            result["rx"] = push.rx
        if push.tx:
            result["tx"] = {str(unit): data for unit, data in push.tx.items()}
    return result


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------


def command_scan(args) -> int:
    device = find_device()
    print(f"VID:PID   {VENDOR_ID:04x}:{PRODUCT_ID:04x}")
    print(f"Product   {device.product}")
    print(f"Vendor    {device.manufacturer}")
    print(f"Serial    {device.serial_number}")
    print(f"Bus/Addr  {device.bus}:{device.address}")
    print("Interfaces:")
    for interface in device.get_active_configuration():
        print(
            f"  {interface.bInterfaceNumber}: class=0x{interface.bInterfaceClass:02x} "
            f"subclass=0x{interface.bInterfaceSubClass:02x} "
            f"protocol=0x{interface.bInterfaceProtocol:02x} "
            f"endpoints={interface.bNumEndpoints}"
        )
        for endpoint in interface:
            direction = "IN" if endpoint.bEndpointAddress & 0x80 else "OUT"
            print(
                f"    ep=0x{endpoint.bEndpointAddress:02x} {direction} "
                f"type={endpoint.bmAttributes & 0x03} max={endpoint.wMaxPacketSize}"
            )
    return 0


def command_monitor(args) -> int:
    device = open_device()
    parser = StreamParser()
    jsonl = Path(args.jsonl).open("a", encoding="utf-8") if args.jsonl else None
    last_status = None
    deadline = time.monotonic() + args.duration if args.duration else None

    print("monitoring; press Ctrl+C to stop", file=sys.stderr)
    try:
        while deadline is None or time.monotonic() < deadline:
            frames = read_frames(device, parser)
            if not frames:
                continue

            for packet in frames:
                if args.raw:
                    print(f"RX  {packet.hex(' ')}")

                info = parse_frame(packet)
                if info is None:
                    continue

                if info["kind"] == "ack":
                    if args.raw or args.verbose:
                        print(summarize(packet))
                    continue

                if info["kind"] != "push":
                    continue

                push = info["push"]
                if push.kind == "level" and not args.levels:
                    if jsonl:
                        _write_jsonl(jsonl, info)
                    continue

                if push.kind == "status":
                    snapshot = (push.rx, push.tx)
                    if snapshot == last_status and not args.raw:
                        if jsonl:
                            _write_jsonl(jsonl, info)
                        continue
                    last_status = snapshot

                print(summarize(packet))
                if jsonl:
                    _write_jsonl(jsonl, info)

    except KeyboardInterrupt:
        print("\nstopped", file=sys.stderr)
    finally:
        if jsonl:
            jsonl.close()
        close_device(device)
    return 0


def _write_jsonl(handle, info: dict) -> None:
    record = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        **frame_to_dict(info),
    }
    handle.write(json.dumps(record, ensure_ascii=False) + "\n")
    handle.flush()


def command_status(args) -> int:
    device = open_device()
    parser = StreamParser()
    latest: dict = {"rx": {}, "tx": {}, "identity": {}}
    deadline = time.monotonic() + args.timeout

    try:
        while time.monotonic() < deadline:
            for packet in read_frames(device, parser, timeout_ms=500):
                info = parse_frame(packet)
                if info is None or info["kind"] != "push":
                    continue
                push = info["push"]
                if push.kind == "identity":
                    latest["identity"] = {
                        "rx": push.rx,
                        "tx": {str(unit): data for unit, data in push.tx.items()},
                    }
                elif push.kind == "status":
                    latest["rx"] = push.rx
                    if args.raw:
                        latest.setdefault("raw", {})["status"] = push.payload.hex(" ")
                    for offset in range(41, len(push.payload) - 31, 32):
                        if push.payload[offset] != 0x02:
                            continue
                        unit = push.payload[offset + 1]
                        if args.raw:
                            latest.setdefault("raw", {})[f"tx{unit}_slot"] = push.payload[
                                offset : offset + 32
                            ].hex(" ")
                    for unit, data in push.tx.items():
                        latest["tx"].setdefault(str(unit), {}).update(data)
                elif push.kind == "level":
                    for unit, data in push.tx.items():
                        latest["tx"].setdefault(str(unit), {}).update(data)

            if latest["rx"] and latest["identity"] and all(
                "input_level" in data for data in latest["tx"].values()
            ):
                break

        print(json.dumps(latest, indent=2, ensure_ascii=False))
        return 0
    finally:
        close_device(device)


def command_set(args) -> int:
    setting = SETTINGS[args.setting]
    try:
        value = setting["convert"](args.value)
    except (KeyError, ValueError):
        raise SystemExit(f"invalid value {args.value!r} for {args.setting}") from None

    target = setting["target"]
    if args.setting == "voice-tone":
        target = {1: ADDRESS_TX1, 2: ADDRESS_TX2}.get(args.tx, ADDRESS_TX1)
    if args.tx is not None:
        target = {1: ADDRESS_TX1, 2: ADDRESS_TX2}.get(args.tx, target)
    if args.target is not None:
        target = args.target

    sequence = random.randrange(0x10000)
    packet = build_command(target, setting["command"], value, sequence)

    print(f"{args.setting} = {args.value}")
    print(f"target=0x{target:04x} cmd=0x{setting['command']:04x} value=0x{value:02x}")
    print(f"TX  {packet.hex(' ')}")

    if args.dry_run:
        return 0

    device = open_device()
    try:
        write_packet(device, packet)
        deadline = time.monotonic() + 2.0
        parser = StreamParser()
        while time.monotonic() < deadline:
            for reply in read_frames(device, parser, timeout_ms=500):
                info = parse_frame(reply)
                if info is None:
                    continue
                if info["kind"] == "ack":
                    print(
                        f"RX  ACK seq={info['sequence']:04x} "
                        f"value=0x{info.get('ack_value', 0):02x} "
                        f"({'ok' if info['sequence'] == sequence else 'other'})"
                    )
                    if info["sequence"] == sequence:
                        if info.get("accepted"):
                            return 0
                        print("command rejected by the receiver", file=sys.stderr)
                        return 3
                elif args.verbose:
                    print(f"RX  {summarize(reply)}")
        print("no matching ACK received", file=sys.stderr)
        return 2
    finally:
        close_device(device)


def command_raw(args) -> int:
    try:
        packet = bytes.fromhex(args.hex.replace(" ", "").replace(":", ""))
    except ValueError:
        raise SystemExit("raw expects hex bytes") from None

    if len(packet) < 13:
        raise SystemExit("packet is too short")

    if packet[0] != 0x55:
        raise SystemExit("raw packet must start with 0x55")
    if crc8(packet[0:3]) != packet[3]:
        raise SystemExit("invalid header CRC-8")

    print(f"TX  {packet.hex(' ')}")
    if args.dry_run:
        return 0

    device = open_device()
    try:
        write_packet(device, packet)
        parser = StreamParser()
        deadline = time.monotonic() + 2.0
        while time.monotonic() < deadline:
            for reply in read_frames(device, parser, timeout_ms=500):
                print(f"RX  {summarize(reply)}")
    finally:
        close_device(device)
    return 0


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    scan = subparsers.add_parser("scan", help="list the receiver USB descriptors")
    scan.set_defaults(func=command_scan)

    monitor = subparsers.add_parser("monitor", help="stream and decode heartbeats")
    monitor.add_argument("--raw", action="store_true", help="print raw hex for every frame")
    monitor.add_argument("--levels", action="store_true", help="print audio level pushes")
    monitor.add_argument("--verbose", action="store_true", help="print ACKs")
    monitor.add_argument("--duration", type=float, default=0, help="seconds (0 = forever)")
    monitor.add_argument("--jsonl", help="append decoded frames to this file")
    monitor.set_defaults(func=command_monitor)

    status = subparsers.add_parser("status", help="read one consolidated snapshot as JSON")
    status.add_argument("--timeout", type=float, default=2.0, help="seconds to wait")
    status.add_argument("--raw", action="store_true", help="include raw status payload and TX slots")
    status.set_defaults(func=command_status)

    set_command = subparsers.add_parser("set", help="send a setting command")
    set_command.add_argument("setting", choices=sorted(SETTINGS))
    set_command.add_argument("value")
    set_command.add_argument("--tx", type=int, choices=(1, 2), help="transmitter unit")
    set_command.add_argument(
        "--target", type=lambda value: int(value, 0), help="override target address (hex or decimal)"
    )
    set_command.add_argument("--dry-run", action="store_true", help="print without sending")
    set_command.add_argument("--verbose", action="store_true")
    set_command.set_defaults(func=command_set)

    raw = subparsers.add_parser("raw", help="send a raw packet")
    raw.add_argument("hex")
    raw.add_argument("--dry-run", action="store_true")
    raw.set_defaults(func=command_raw)

    args = parser.parse_args(argv)
    try:
        return args.func(args)
    except RuntimeError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    except usb.core.USBError as error:
        print(f"USB error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
