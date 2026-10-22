from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools" / "poc"))

from dji_protocol import (  # noqa: E402
    ADDRESS_ALL_TX,
    ADDRESS_TX1,
    StreamParser,
    build_command,
    crc8,
    crc16,
    parse_frame,
)


STATUS_1TX = bytes.fromhex(
    "55 56 04 67 5a 02 00 00 00 5b 03 03 46 00 03 00 00 00 00 20 28 01 "
    "00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 01 "
    "00 00 00 2e 00 00 00 02 01 00 00 00 1a 30 25 00 a9 00 78 00 00 00 00 "
    "00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 94 55"
)

IDENTITY_RX_TX1 = bytes.fromhex(
    "55 80 04 95 5a 02 00 00 00 5b 03 03 70 00 01 00 00 00 00 12 00 11 03 "
    "02 42 33 4e 58 4e 42 34 30 32 32 52 46 36 53 04 00 00 00 00 06 65 64 "
    "61 36 33 30 06 00 00 00 00 0e 44 4a 49 20 4d 69 63 20 4d 69 6e 69 20 "
    "32 01 01 00 00 00 12 00 11 03 02 42 33 4d 54 50 33 4e 30 31 35 5a 58 "
    "4d 5a 04 01 00 00 00 06 61 66 62 30 36 64 06 01 00 00 00 0e 44 4a 49 "
    "20 4d 69 63 20 4d 69 6e 69 20 32 c8 c3"
)

LEVEL_TX1 = bytes.fromhex(
    "55 17 04 38 5a 02 00 00 00 5b 03 03 07 00 05 01 00 00 00 01 1e 99 22"
)


def make_ack(sequence: int, value: int) -> bytes:
    packet = bytearray(14)
    packet[0] = 0x55
    packet[1] = 0x0E
    packet[2] = 0x04
    packet[3] = crc8(packet[0:3])
    packet[4] = 0x5A
    packet[5] = 0x02
    packet[6:8] = sequence.to_bytes(2, "little")
    packet[8] = 0x80
    packet[9] = 0x5B
    packet[10] = 0x01
    packet[11] = value
    packet[12:14] = crc16(packet[0:12]).to_bytes(2, "little")
    return bytes(packet)


class FramingTests(unittest.TestCase):
    def test_build_command_shape(self):
        packet = build_command(0xFFFF, 0x0038, 1, 0x1234)
        self.assertEqual(len(packet), 22)
        self.assertEqual(packet[0], 0x55)
        self.assertEqual(packet[3], 0xFC)
        self.assertEqual(crc8(packet[0:3]), packet[3])
        self.assertEqual(crc16(packet[0:20]), int.from_bytes(packet[20:22], "little"))

    def test_stream_parser_handles_split_frames(self):
        parser = StreamParser()
        self.assertEqual(parser.feed(STATUS_1TX[:10]), [])
        frames = parser.feed(STATUS_1TX[10:] + LEVEL_TX1)
        self.assertEqual(len(frames), 2)
        self.assertEqual(frames[0], STATUS_1TX)

    def test_parser_rejects_bad_crc(self):
        broken = bytearray(STATUS_1TX)
        broken[-1] ^= 0x01
        parser = StreamParser()
        self.assertEqual(parser.feed(bytes(broken)), [])


class DecodingTests(unittest.TestCase):
    def test_status_with_tx1(self):
        info = parse_frame(STATUS_1TX)
        push = info["push"]
        self.assertEqual(push.kind, "status")
        self.assertTrue(push.rx["noise_cancel"])
        self.assertTrue(push.rx["noise_cancel_strong"])
        self.assertEqual(push.rx["gain"], 0)
        self.assertFalse(push.rx["stereo"])
        tx = push.tx[1]
        self.assertTrue(tx["noise_cancel"])
        self.assertTrue(tx["noise_cancel_strong"])
        self.assertTrue(tx["low_cut"])
        self.assertFalse(tx["leds_off"])
        self.assertEqual(tx["voice_tone"], "bright")
        self.assertFalse(tx["clipping_control"])
        self.assertEqual(tx["battery_gauge"], 1)
        self.assertTrue(tx["battery_full"])
        self.assertFalse(tx["charging"])
        self.assertFalse(tx["muted"])
        self.assertFalse(tx["recording"])
        self.assertTrue(tx["float32_recording"])
        self.assertTrue(tx["vibration"])
        self.assertTrue(tx["rec_stop_lock"])
        self.assertFalse(tx["startup_auto_recording"])
        self.assertEqual(tx["recording_time_total"], 0.0)
        self.assertEqual(tx["recording_time_remaining"], 0.0)

    def test_identity(self):
        info = parse_frame(IDENTITY_RX_TX1)
        push = info["push"]
        self.assertEqual(push.rx["product_name"], "DJI Mic Mini 2")
        self.assertEqual(push.rx["firmware"], "02.03.17.00")
        self.assertEqual(push.tx[1]["product_name"], "DJI Mic Mini 2")
        self.assertEqual(push.tx[1]["firmware"], "02.03.17.00")

    def test_level(self):
        info = parse_frame(LEVEL_TX1)
        self.assertEqual(info["push"].tx[1]["input_level"], 30)

    def test_ack_accept_and_reject(self):
        accepted = parse_frame(make_ack(0x1234, 0x00))
        self.assertEqual(accepted["kind"], "ack")
        self.assertTrue(accepted["accepted"])
        rejected = parse_frame(make_ack(0x1235, 0xFF))
        self.assertFalse(rejected["accepted"])


class DiscoveryCommandTests(unittest.TestCase):
    def test_new_settings_are_wired(self):
        from dji_probe import SETTINGS

        expected = {
            "mute": (0x0009, ADDRESS_TX1),
            "rec": (0x0002, ADDRESS_TX1),
            "vibration": (0x0004, ADDRESS_ALL_TX),
            "float32": (0x000C, ADDRESS_ALL_TX),
            "rec-stop-lock": (0x000B, ADDRESS_ALL_TX),
            "startup-auto-recording": (0x002E, ADDRESS_ALL_TX),
        }

        for name, (command, target) in expected.items():
            setting = SETTINGS[name]
            self.assertEqual(setting["command"], command)
            self.assertEqual(setting["target"], target)
            self.assertEqual(setting["convert"]("on"), 1)
            self.assertEqual(setting["convert"]("off"), 0)


if __name__ == "__main__":
    unittest.main()
