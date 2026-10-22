# Notas do protocolo — DJI Mic Mini 2 (RX `2ca3:4011`)

Documento interno, escrito a partir de observação do dispositivo e de fatos
públicos do protocolo. Não contém código nem texto copiado de outros projetos.
As fontes consultadas estão em `references.md`.

## Transporte

- Interface USB 6, bulk.
- Host → RX: endpoint `0x06`.
- RX → host: endpoint `0x86`.
- Pacotes de 64 bytes ou múltiplos; o parser deve varrer o stream.

## Enquadramento (DUML v2)

```
55 LL VV C8 02 5A SEQ_L SEQ_H 40 5B 01 02 TGT_L TGT_H 00 00 CMD_L CMD_H 01 VAL C16_L C16_H
```

| Offset | Tamanho | Significado |
|---|---|---|
| 0 | 1 | `0x55` |
| 1 | 2 | tamanho total em bits 0–9; versão do protocolo em bits 10–15 |
| 3 | 1 | CRC-8 de `0..2` |
| 4 | 1 | origem (`0x02`) |
| 5 | 1 | flags (`0x5a`) |
| 6 | 2 | sequência, little-endian |
| 8 | 1 | `0x40` = pede ACK |
| 9 | 1 | command set (`0x5b` para áudio) |
| 10 | 1 | `0x01` |
| 11 | 1 | `0x02` = comando endereçado |
| 12 | 2 | target, little-endian |
| 14 | 2 | reservado |
| 16 | 2 | command id, little-endian |
| 18 | 1 | tamanho do payload (1) |
| 19 | 1 | valor |
| 20 | 2 | CRC-16, little-endian |

- CRC-8: polinômio refletido `0x31`, init `0x77`, calculado sobre os bytes
  `0..2`. O valor de `packet[3]` para comandos de 22 bytes é `0xfc`.
- CRC-16: polinômio refletido `0x8408`, init `0x3692`, calculado sobre o
  pacote inteiro menos os dois bytes de CRC.
- O parser valida CRC-8 e CRC-16 antes de aceitar um frame.

Targets:

| Target | Destino |
|---|---|
| `0x0000` | receptor (RX) |
| `0x0001` / `0x0002` | TX1 / TX2 |
| `0xffff` | broadcast para os TXs |

## ACK

O RX responde a cada comando com um frame de 14 bytes, ecoando a sequência:

- byte 8 = `0x80`
- byte 11 = resultado: **`0x00` aceito**, **`0xff` rejeitado**

Exemplo observado: `noise-cancel off` → ACK com `0xff` (rejeitado);
`gain 6` → ACK com `0x00` (aceito).

Existem também frames de 14 bytes com byte 8 = `0x00`, command set `0x5b`,
id `0x04`, que aparecem periodicamente e não são ACK. O probe ignora esses
frames por enquanto.

## Pushes periódicos

Todos usam command set `0x5b`, command id `0x03`. O payload começa em
`packet[11]`; `payload[3]` identifica o tipo:

| `payload[3]` | Tipo | Conteúdo |
|---|---|---|
| `0x01` | identidade | nome, serial, firmware, sufixo de endereço |
| `0x03` | status | estado do RX e slots dos TXs |
| `0x05` | nível | nível de entrada por TX |

### Status (tipo `0x03`)

Payload de 41 bytes sem TX; 73 bytes com 1 TX; 105 com 2 TXs.
Slots de TX começam em `payload[41]`, 32 bytes cada.

Campos do RX confirmados no Mic Mini 2:

| Offset no payload | Campo |
|---|---|
| 9 | bits `0x20` = NC ligado, `0x08` = NC Strong |
| 10 | bit `0x04` = stereo |
| 11 | gain do RX, int8 (dB) |
| 16 | monitoring gain, int8 (dB) |
| 37 | bit `0x40` = safety track |
| 37 | bit `0x10` = clipping control |
| 10 | bit `0x01` = auto-off do RX |

O NC **não** é escrito por comando neste kit: o receptor tem uma chave física
O/L/H. Os comandos `0x37`/`0x38` retornam `0xff`.

O receptor é alimentado pelo USB e não expõe bateria própria; a bateria
disponível no protocolo é a do TX.

### Slot de TX (32 bytes)

Base = `payload[41] + 32 * índice`. O byte `base+1` identifica a unidade
física (`0x01` = TX1, `0x02` = TX2).

| Offset | Campo |
|---|---|
| +6 | `0x20` = NC Strong, `0x10` = auto-off do TX, `0x08` = timer de auto-off ativo, `0x80` = NC via botão, `0x02` = LEDs desligados |
| +7 | `0x01` = NC ligado; `0x02` = carregando; bits 2–4 = bateria (1 cheio … 7 vazio) |
| +8 | `0x04` = clipping control (espelha o RX) |
| +9 | `0x20` = low cut, `0x40` = voice tone Rich, `0x80` = voice tone Bright |

### Identidade (tipo `0x01`)

- RX: serial em `payload[13:27]`, firmware em `payload[9:13]` (ordem
  reversa), sufixo em `payload[33:39]`, nome em `payload[45]` com tamanho em
  `payload[44]`.
- TX: registros de 42 bytes a partir de `45 + payload[44]`. O nome fica em
  `base+42`, o serial em `base+10` e o firmware em `base+6`.

Valores observados nesta unidade:

- RX: `DJI Mic Mini 2`, firmware `02.03.17.00`
- TX1: `DJI Mic Mini 2`, firmware `02.03.17.00`
- Sufixo de endereço do RX: `eda630`

### Nível (tipo `0x05`)

Slots de 7 bytes a partir de `payload[3]`. `payload[3] = 0x05`,
`payload[4]` = unidade, `payload[9]` = nível.

## Comandos validados

| Ajuste | Cmd | Target | Valor | Leitura |
|---|---|---|---|---|
| Gain | `0x0039` | RX | int8 | status `payload[11]` |
| Monitoring gain | `0x0026` | RX | int8 | status `payload[16]` |
| Safety track | `0x0021` | RX | 0/1 | status `payload[37]` bit 6 |
| Mono/Stereo | `0x0008` | RX | 0 / 2 | status `payload[10]` bit 2 |
| Low cut | `0x0003` | broadcast | 0/1 | slot TX `+9` bit 5 |
| LEDs (Mic LED) | `0x000a` | broadcast | 0 = on, 2 = off | slot TX `+6` bit 1 |
| Voice tone | `0x0029` | TX1/TX2 | 0/1/2 | slot TX `+9` bits 6–7 |
| Clipping control | `0x001e` ou `0x0024` | RX | 0/1 | RX `payload[37]` bit 4 e TX slot `+8` bit 2 |
| Auto-off do TX | `0x0010` | broadcast | 0/1 | slot TX `+6` bit 4 |
| Auto-off do RX | `0x0010` | RX | 0/1 | RX `payload[10]` bit 0 |
| Bateria do TX | — | — | leitura | slot TX `+7` bits 2–4; `+7` bit 1 = carregando |
| NC ligado/forte | `0x0038` / `0x0037` | qualquer | — | **rejeitado (`0xff`)** |
