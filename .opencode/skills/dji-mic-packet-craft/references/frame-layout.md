# Frame layout — referência rápida

## Comando (22 bytes)

```
55 16 04 FC 02 5A SEQ_L SEQ_H 40 5B 01 02 TGT_L TGT_H 00 00 CMD_L CMD_H 01 VAL CRC_L CRC_H
```

| Offset | Bytes | Campo |
|---|---|---|
| 0 | 1 | `0x55` |
| 1 | 2 | comprimento (10 bits) + versão (6 bits), LE |
| 3 | 1 | CRC-8 de 0–2 |
| 4 | 1 | `0x02` |
| 5 | 1 | `0x5A` |
| 6 | 2 | sequência LE |
| 8 | 1 | `0x40` pede ACK |
| 9 | 1 | `0x5B` |
| 10 | 1 | `0x01` |
| 11 | 1 | `0x02` comando endereçado |
| 12 | 2 | target LE |
| 14 | 2 | reservado |
| 16 | 2 | command id LE |
| 18 | 1 | payload length = 1 |
| 19 | 1 | valor |
| 20 | 2 | CRC-16 LE |

## CRC

CRC-8:
- init `0x77`
- polinômio refletido `0x31`
- bytes 0–2
- comando de 22 bytes → `0xFC`

CRC-16:
- init `0x3692`
- polinômio refletido `0x8408`
- todos os bytes menos os 2 últimos
- armazenar LE

## Verificação

1. `packet[0] == 0x55`
2. `(length & 0x3FF) == len(packet)`
3. `crc8(packet[0:3]) == packet[3]`
4. `crc16(packet[:-2]) == LE(packet[-2:])`

## ACK (14 bytes)

```
55 0E 04 66 5A 02 SEQ_L SEQ_H 80 5B 01 RESULT CRC_L CRC_H
```

- `byte 8 = 0x80`
- `byte 11 = 0x00` aceito
- `byte 11 = 0xFF` rejeitado
- CRC-8 de 14 bytes = `0x66`

## Push

```
55 LL 04 C8 5A 02 SEQ_L SEQ_H 00 5B 03 PAYLOAD... CRC_L CRC_H
```

- command set `0x5B`
- command id `0x03`
- payload começa em `packet[11]`
- `payload[3]`: `0x01` identidade, `0x03` status, `0x05` nível

## Escalas

- gain/monitoring: int8
- voice tone: 0 regular, 1 rich, 2 bright
- stereo: 0 mono, 2 stereo
- mic LED: 0 on, 2 off
- NC: read-only
- bateria: `(byte >> 2) & 0x07`
