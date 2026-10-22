---
name: DJI Mic Packet Craft
description: Use when building, decoding, or debugging DJI Mic DUML packets, CRC-8/CRC-16, command targets, status offsets, identity/level pushes, or adding a new MicSetting command.
---

# DJI Mic Packet Craft

Skill autocontida para montar e decodificar frames do DJI Mic Mini 2 RX.
Não depende de outros documentos para funcionar.

## Escopo

Use para:

- montar um comando de 22 bytes;
- calcular CRC-8 e CRC-16;
- escolher target;
- interpretar ACK;
- ler status, identidade e nível;
- adicionar um `MicSetting` ao Python ou ao Swift;
- depurar offsets.

Não use para:

- testar no hardware (use `dji-mic-hardware-validation`);
- descobrir comandos desconhecidos (use `dji-mic-protocol-discovery`);
- resolver acesso USB (use `dji-mic-usb-transport`).

## Contexto fixo

- RX: `0x2ca3:0x4011`, interface 6.
- OUT: `0x06`; IN: `0x86`.
- Firmware observado: `02.03.17.00`.
- Produto: `DJI Mic Mini 2`.
- NC é read-only (chave O/L/H).
- Bateria é gauge de 7 níveis.

## Frame de comando (22 bytes)

```
55 16 04 FC 02 5A SEQ_L SEQ_H 40 5B 01 02 TGT_L TGT_H 00 00 CMD_L CMD_H 01 VAL CRC_L CRC_H
```

| Offset | Campo |
|---|---|
| 0 | `0x55` |
| 1 | comprimento 22 (`0x16`) |
| 2 | versão `0x04` |
| 3 | CRC-8 de 0–2 (`0xFC` para 22 bytes) |
| 4 | `0x02` |
| 5 | `0x5A` |
| 6–7 | sequência LE |
| 8 | `0x40` (pede ACK) |
| 9 | `0x5B` |
| 10 | `0x01` |
| 11 | `0x02` (comando endereçado) |
| 12–13 | target LE |
| 14–15 | zero |
| 16–17 | command id LE |
| 18 | `0x01` |
| 19 | valor |
| 20–21 | CRC-16 LE |

Targets:

| Target | Destino |
|---|---|
| `0x0000` | RX |
| `0x0001` | TX1 |
| `0x0002` | TX2 |
| `0xFFFF` | broadcast TX |

## CRC

CRC-8:

- polinômio refletido `0x31`
- init `0x77`
- sobre bytes 0–2
- para 22 bytes: `0xFC`

CRC-16:

- polinômio refletido `0x8408`
- init `0x3692`
- sobre o pacote inteiro menos os 2 bytes finais
- little-endian no fim

Python:

```python
def crc8(data: bytes) -> int:
    c = 0x77
    for b in data:
        c ^= b
        for _ in range(8):
            c = (c >> 1) ^ (0x8C if c & 1 else 0)
    return c

def crc16(data: bytes) -> int:
    c = 0x3692
    for b in data:
        c ^= b
        for _ in range(8):
            c = (c >> 1) ^ (0x8408 if c & 1 else 0)
    return c
```

Swift: `Sources/DJIMicProtocol/CRC.swift`.
Script autocontido: `scripts/build_frame.py`.

## ACK

14 bytes:

```
55 0E 04 66 5A 02 SEQ_L SEQ_H 80 5B 01 RESULT CRC_L CRC_H
```

- `byte 8 == 0x80` identifica ACK.
- `byte 11 == 0x00` aceito.
- `byte 11 == 0xFF` rejeitado.
- Compare a sequência.
- Frames `5B 04` com payload `0x09` não são ACK; ignore.

## Pushes

Command set `0x5B`, command id `0x03`. Payload começa em `packet[11]`.
`payload[3]`:

| Tipo | Significado |
|---|---|
| `0x01` | identidade |
| `0x03` | status |
| `0x05` | nível |

### Status RX

Payload: 41 bytes sem TX, 73 com 1 TX, 105 com 2 TXs.
Slots de TX em `payload[41]`, 32 bytes cada.

| Offset | Campo |
|---|---|
| 9 | `0x20` NC on; `0x08` NC Strong |
| 10 | `0x04` stereo; `0x01` auto-off RX |
| 11 | gain int8 |
| 16 | monitoring gain int8 |
| 37 | `0x40` safety track; `0x10` clipping |

### Status TX

| Offset | Campo |
|---|---|
| +0 | `0x02` |
| +1 | unidade: `0x01` TX1, `0x02` TX2 |
| +6 | `0x20` NC Strong; `0x10` auto-off; `0x08` timer ativo; `0x80` NC via botão; `0x02` LEDs off |
| +7 | `0x01` NC on; `0x02` charging; bits 2–4 gauge |
| +8 | `0x04` clipping |
| +9 | `0x20` low cut; `0x40` rich; `0x80` bright |

Gauge: `(byte >> 2) & 0x07`; 1 full, 6 low, 7 empty.

### Identidade

- RX serial `payload[13:27]`
- RX firmware `payload[9:13]` invertido
- RX sufixo `payload[33:39]`
- RX nome `payload[45]`, tamanho em `payload[44]`
- TX: registros de 42 bytes a partir de `45 + payload[44]`
  - nome `base+42`
  - serial `base+10`
  - firmware `base+6`
  - sufixo `base+30`

### Nível

Slots de 7 bytes a partir de `payload[3]`:

- `payload[3] = 0x05`
- `payload[4]` = unidade
- `payload[9]` = nível

## Comandos validados

| Ajuste | Cmd | Target | Valores |
|---|---|---|---|
| Gain | `0x0039` | RX | int8 |
| Monitoring gain | `0x0026` | RX | int8 |
| Safety track | `0x0021` | RX | 0/1 |
| Mono/Stereo | `0x0008` | RX | 0/2 |
| Low cut | `0x0003` | broadcast | 0/1 |
| Mic LED | `0x000A` | broadcast | 0 on, 2 off |
| Voice tone | `0x0029` | TX1/TX2 | 0/1/2 |
| Clipping | `0x001E` ou `0x0024` | RX | 0/1 |
| Auto-off TX | `0x0010` | broadcast | 0/1 |
| Auto-off RX | `0x0010` | RX | 0/1 |
| NC on/off | `0x0038` | qualquer | rejeitado |
| NC Basic/Strong | `0x0037` | qualquer | rejeitado |

## Exemplos

Gain 0 no RX, sequência `0x29A3`:

```
55 16 04 fc 02 5a a3 29 40 5b 01 02 00 00 00 00 39 00 01 00 7a 7a
```

NC off rejeitado:

```
55 16 04 fc 02 5a 57 e5 40 5b 01 02 ff ff 00 00 38 00 01 00 02 c1
```

## Workflow para montar um comando

1. Escolha o ajuste na tabela.
2. Defina o target correto.
3. Converta o valor para 1 byte (int8 usa two's complement).
4. Gere a sequência (0–65535).
5. Monte os 22 bytes.
6. Calcule CRC-8 e coloque em `[3]`.
7. Calcule CRC-16 e coloque em `[20:22]` LE.
8. Verifique o frame com `scripts/build_frame.py --verify`.
9. Para enviar no hardware, use `dji-mic-hardware-validation`.

## Adicionar um `MicSetting`

No projeto:

1. `Sources/DJIMicProtocol/Settings.swift`
2. `tools/poc/dji_probe.py` (`SETTINGS`)
3. leitura em `Sources/DJIMicProtocol/DUML.swift`
4. UI em `Sources/DJIMicUI/`
5. testes em `tests/DJIMicProtocolTests/`
6. validação no hardware

## Pitfalls

- CRC-16 é calculado sobre o frame **sem** os dois bytes finais.
- CRC-8 não é checksum de roteamento; depende do comprimento.
- Target e command id são little-endian.
- Gain negativo é int8 (`-6 = 0xFA`).
- Mic LED é invertido: `0` liga, `2` desliga.
- Stereo usa `2`, não `1`.
- Voice tone é por TX, não broadcast.
- NC não é gravável.
- Não invente offsets com base em outros modelos.

## Referências internas

- `references/frame-layout.md`
- `references/commands.md`
- `references/status-offsets.md`
- `scripts/build_frame.py`

## Referência externa opcional

Não necessária para executar:

- `docs/reverse-engineering-handbook.md`
- `docs/protocol-notes.md`
