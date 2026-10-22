# Settings do app

| Setting | Swift case | Cmd | Target | Valores |
|---|---|---|---|---|
| Gain | `.gain(Int)` | `0x0039` | RX | int8 |
| Monitoring | `.monitoringGain(Int)` | `0x0026` | RX | int8 |
| Safety | `.safetyTrack(Bool)` | `0x0021` | RX | 0/1 |
| Stereo | `.stereo(Bool)` | `0x0008` | RX | 0/2 |
| Low cut | `.lowCut(Bool)` | `0x0003` | broadcast | 0/1 |
| Mic LED | `.micLED(Bool)` | `0x000A` | broadcast | 0 on/2 off |
| Voice tone | `.voiceTone(VoiceTone, unit:)` | `0x0029` | TX1/TX2 | 0/1/2 |
| Clipping | `.clippingControl(Bool)` | `0x001E` | RX | 0/1 |
| Auto-off TX | `.autoOffTX(Bool)` | `0x0010` | broadcast | 0/1 |
| Auto-off RX | `.autoOffRX(Bool)` | `0x0010` | RX | 0/1 |

## Leitura

| Setting | Status |
|---|---|
| Gain | `payload[11]` |
| Monitoring | `payload[16]` |
| Safety | `payload[37]` bit 6 |
| Stereo | `payload[10]` bit 2 |
| Low cut | TX `+9` bit 5 |
| Mic LED | TX `+6` bit 1 (invertido) |
| Voice tone | TX `+9` bits 6–7 |
| Clipping | RX `[37]` bit 4 + TX `+8` bit 2 |
| Auto-off TX | TX `+6` bit 4 |
| Auto-off RX | `payload[10]` bit 0 |

## Voice tone

```swift
enum VoiceTone {
    case regular  // 0
    case rich     // 1
    case bright   // 2
}
```

## Adicionar

1. `MicSetting` case.
2. `command`.
3. `id`.
4. leitura no parser.
5. UI binding.
6. i18n.
7. teste.
8. validação.
