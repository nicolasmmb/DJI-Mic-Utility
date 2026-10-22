# Status, identidade e nível

## Status — payload[3] == 0x03

Tamanhos de payload:

- 41 bytes: sem TX (frame 54)
- 73 bytes: 1 TX (frame 86)
- 105 bytes: 2 TXs (frame 118)

Slots de TX: começam em `payload[41]`, 32 bytes cada.

## Campos do RX

| Offset | Campo |
|---|---|
| 9 | `0x20` NC on; `0x08` NC Strong |
| 10 | `0x04` stereo; `0x01` auto-off RX |
| 11 | gain int8 |
| 16 | monitoring gain int8 |
| 37 | `0x40` safety; `0x10` clipping |
| 35 | desconhecido (observado `0x2e`/`0x3e`) |

## Slot do TX

| Offset | Campo |
|---|---|
| +0 | `0x02` |
| +1 | `0x01` TX1, `0x02` TX2 |
| +2..4 | zero |
| +5 | `0x1A` (26) |
| +6 | `0x20` NC Strong; `0x10` auto-off; `0x08` timer ativo; `0x80` NC via botão; `0x02` LEDs off |
| +7 | `0x01` NC on; `0x02` charging; bits 2–4 gauge |
| +8 | `0x04` clipping |
| +9 | `0x20` low cut; `0x40` rich; `0x80` bright |
| +10 | zero |
| +11 | `0x78` |
| +12..31 | zero |

Gauge: `(payload[base+7] >> 2) & 0x07`.

## Identidade — payload[3] == 0x01

RX:

- serial `payload[13:27]`
- firmware `payload[9:13]` invertido
- sufixo `payload[33:39]`
- nome `payload[45]`, tamanho em `payload[44]`

TX:

- registros de 42 bytes a partir de `45 + payload[44]`
- nome `base+42`
- serial `base+10`
- firmware `base+6`
- sufixo `base+30`

## Nível — payload[3] == 0x05

Slots de 7 bytes a partir de `payload[3]`:

- `payload[3] = 0x05`
- `payload[4]` = unidade
- `payload[9]` = nível

## Exemplo de status com 1 TX

```
55 56 04 67 5a 02 00 00 00 5b 03 03 46 00 03 00 00 00 00 20 00 01 06
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 01 00
00 00 3e 00 00 00 02 01 00 00 00 1a 38 24 04 89 00 78 00 00 00 00 00
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 bc 26
```

Neste frame:

- RX: NC off, gain 6, monitoring 0, clipping on
- TX1: slot em `payload[41]`: `02 01 ... 38 24 04 89`

## Exemplo de identidade

```
55 80 04 95 5a 02 00 00 00 5b 03 03 70 00 01 00 00 00 00 12 00 11 03
02 42 33 4e 58 4e 42 34 30 32 32 52 46 36 53 04 00 00 00 00 06 65 64
61 36 33 30 06 00 00 00 00 0e 44 4a 49 20 4d 69 63 20 4d 69 6e 69 20
32 01 01 00 00 00 12 00 11 03 02 42 33 4d 54 50 33 4e 30 31 35 5a 58
4d 5a 04 01 00 00 00 06 61 66 62 30 36 64 06 01 00 00 00 0e 44 4a 49
20 4d 69 63 20 4d 69 6e 69 20 32 c8 c3
```

## Exemplo de nível

```
55 17 04 38 5a 02 00 00 00 5b 03 03 07 00 05 01 00 00 00 01 1e 99 22
```

`payload[9] = 0x1E` → nível 30.
