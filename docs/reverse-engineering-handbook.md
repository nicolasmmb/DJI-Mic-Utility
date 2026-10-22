# Handbook de engenharia reversa — DJI Mic Mini 2 RX

Manual prático de como o protocolo foi descoberto, como montar e enviar
mensagens, como validar comandos e como depurar o app.

Ele complementa:

- [`protocol-notes.md`](protocol-notes.md) — referência canônica dos frames
- [`feature-matrix.md`](feature-matrix.md) — resultados no hardware
- [`references.md`](references.md) — fontes consultadas
- [`PROJECT-CONTEXT.md`](PROJECT-CONTEXT.md) — histórico e decisões

## 1. Princípios

1. **Validar antes de implementar.** Nenhum comando entra na UI sem ACK e
   mudança de estado observados.
2. **Uma variável por vez.** Alterar um ajuste, comparar o status antes/depois.
3. **O dispositivo é a fonte da verdade.** A UI nunca deve “achar” que o
   comando funcionou.
4. **Sem código de terceiros.** Referências externas são só informação.
5. **Nada destrutivo.** Sem firmware update, formatação ou reboot sem pesquisa
   e confirmação.

## 2. Ambiente

- macOS 27 / Xcode 27.1 / Swift 6.4
- Python 3.12 via `uv`
- `pyusb` 1.3.1
- libusb via Homebrew
- IOKit nativo no app Swift

Ferramentas internas:

| Ferramenta | Caminho | Uso |
|---|---|---|
| POC Python | `tools/poc/` | descoberta e validação rápida |
| Probe Swift | `Sources/DJIMicProbe/` | validação do transporte/app |
| App | `Sources/DJIMicApp/` | produto final |
| Testes Swift | `tests/DJIMic*Tests/` | protocolo, sessão, UI |
| Testes Python | `tests/test_protocol.py` | regressão do POC |
| Build do app | `Scripts/build-app.sh` | gera `Release/DJIMic.app` |

## 3. Reconhecimento USB

### 3.1 Listar descritores

```bash
system_profiler SPUSBDataType | grep -A20 -i 'wireless mic'
ioreg -p IOUSB -l -w0 | grep -E 'Wireless Mic|idVendor|idProduct'
ioreg -r -n 'Wireless Mic Rx@02100000' -l -w0
ioreg -r -n 'IOUSBHostInterface@6' -l -w0
```

O que importa:

- `idVendor = 0x2ca3`
- `idProduct = 0x4011`
- interface de controle = 6
- endpoints bulk = `0x06` OUT e `0x86` IN

A interface 0 é HID (botões). Não é o canal de configuração.

### 3.2 Ver o áudio

```bash
system_profiler SPAudioDataType | grep -A8 -i 'wireless mic'
```

O RX aparece como entrada USB de 2 canais. O áudio continua funcionando mesmo
com o app controlando a interface 6.

### 3.3 Ver quem está com a interface

```bash
ioreg -r -n 'IOUSBHostInterface@6' -l -w0 | grep -E 'UsbExclusiveOwner|IOUserClientCreator'
```

Se `DJIMicApp` aparecer, feche o app antes de rodar o POC Python.

## 4. Anatomia do frame

### 4.1 Comando (22 bytes)

```
55 16 04 FC 02 5A SEQ_L SEQ_H 40 5B 01 02 TGT_L TGT_H 00 00 CMD_L CMD_H 01 VAL CRC_L CRC_H
```

| Offset | Bytes | Campo |
|---|---|---|
| 0 | 1 | `0x55` start of frame |
| 1 | 2 | comprimento (10 bits) + versão (6 bits), LE |
| 3 | 1 | CRC-8 dos bytes 0–2 |
| 4 | 1 | `0x02` origem |
| 5 | 1 | `0x5A` flags |
| 6 | 2 | sequência, LE |
| 8 | 1 | `0x40` pede ACK |
| 9 | 1 | command set `0x5B` |
| 10 | 1 | `0x01` |
| 11 | 1 | `0x02` comando endereçado |
| 12 | 2 | target, LE |
| 14 | 2 | reservado |
| 16 | 2 | command id, LE |
| 18 | 1 | tamanho do payload (`1`) |
| 19 | 1 | valor |
| 20 | 2 | CRC-16, LE |

Targets:

| Target | Destino |
|---|---|
| `0x0000` | RX |
| `0x0001` | TX1 |
| `0x0002` | TX2 |
| `0xFFFF` | broadcast para os TXs |

### 4.2 CRC

- **CRC-8:** polinômio refletido `0x31`, init `0x77`, sobre os bytes 0–2.
  Para um comando de 22 bytes, `packet[3] == 0xFC`.
- **CRC-16:** polinômio refletido `0x8408`, init `0x3692`, sobre todos os
  bytes menos os dois últimos, que são o CRC little-endian.

Implementações canônicas:

- Python: `tools/poc/dji_protocol.py` (`crc8`, `crc16`)
- Swift: `Sources/DJIMicProtocol/CRC.swift`

### 4.3 Exemplo de comando validado

Gain do RX para `0`, sequência `0x29A3`:

```
55 16 04 fc 02 5a a3 29 40 5b 01 02 00 00 00 00 39 00 01 00 7a 7a
```

Leitura:

- target `0x0000` (RX)
- command `0x0039`
- valor `0x00` (0 dB)
- CRC-16 `0x7A7A`

### 4.4 Exemplo de comando rejeitado

NC off (`0x38 = 0`), broadcast:

```
55 16 04 fc 02 5a 57 e5 40 5b 01 02 ff ff 00 00 38 00 01 00 02 c1
```

O RX responde ACK com `0xff`; não há mudança de estado. Isso é esperado no
Mic Mini 2 por causa da chave física O/N.

## 5. ACK

O ACK tem 14 bytes:

```
55 0e 04 66 5a 02 SEQ_L SEQ_H 80 5b 01 RESULT CRC_L CRC_H
```

| Offset | Campo |
|---|---|
| 0 | `0x55` |
| 1 | `0x0E` comprimento |
| 2 | `0x04` versão |
| 3 | CRC-8 (`0x66` para 14 bytes) |
| 4 | `0x5A` |
| 5 | `0x02` |
| 6 | sequência ecoada |
| 8 | `0x80` marca ACK |
| 9 | `0x5B` |
| 10 | `0x01` |
| 11 | resultado: `0x00` aceito, `0xFF` rejeitado |
| 12 | CRC-16 LE |

Regras:

- Sempre compare a sequência.
- Ignore ACK antigo de comando já resolvido.
- Um comando aceito pode ser confirmado no próximo status; o ACK só diz que o
  RX aceitou o pedido.
- Existem frames de 14 bytes com `byte 8 = 0x00`, `5b 04`, payload `0x09` que
  **não são ACK**. O probe ignora.

## 6. Pushes periódicos

Todos usam `command set 0x5B`, `command id 0x03`. O payload começa em
`packet[11]` e termina antes do CRC. `payload[3]` identifica o tipo:

| `payload[3]` | Tipo |
|---|---|
| `0x01` | identidade |
| `0x03` | status |
| `0x05` | nível |

### 6.1 Status

Tamanhos:

- sem TX: 54 bytes de frame, 41 de payload
- 1 TX: 86 bytes de frame, 73 de payload
- 2 TXs: 118 bytes de frame, 105 de payload

Slots de TX começam em `payload[41]` e têm 32 bytes cada.

Campos do RX:

| Offset | Campo |
|---|---|
| 9 | bit `0x20` NC ligado; bit `0x08` NC Strong |
| 10 | bit `0x04` stereo; bit `0x01` auto-off RX |
| 11 | gain, int8 |
| 16 | monitoring gain, int8 |
| 37 | bit `0x40` safety track; bit `0x10` clipping control |
| 35 | byte ainda não identificado (observado `0x2e`/`0x3e`) |

Slot de TX:

| Offset | Campo |
|---|---|
| +0 | `0x02` tag do slot |
| +1 | unidade física: `0x01` TX1, `0x02` TX2 |
| +6 | `0x20` NC Strong; `0x10` auto-off; `0x08` timer de auto-off ativo; `0x80` NC via botão; `0x02` LEDs desligados |
| +7 | `0x01` NC ligado; `0x02` carregando; bits 2–4 gauge de bateria |
| +8 | `0x04` clipping control |
| +9 | `0x20` low cut; `0x40` voice tone Rich; `0x80` voice tone Bright |

Bateria:

- `(byte >> 2) & 0x07`
- `1` = cheio
- `6` = aviso de bateria baixa
- `7` = vazio
- `0` não observado

### 6.2 Identidade

- RX: serial em `payload[13:27]`, firmware em `payload[9:13]` (invertido),
  sufixo em `payload[33:39]`, nome em `payload[45]` com tamanho em
  `payload[44]`.
- TX: registros de 42 bytes a partir de `45 + payload[44]`.
  - nome em `base+42`
  - serial em `base+10`
  - firmware em `base+6`
  - sufixo em `base+30`

Exemplo observado:

```
55 80 04 95 5a 02 00 00 00 5b 03 03 70 00 01 00 00 00 00 12 00 11 03
02 42 33 4e 58 4e 42 34 30 32 32 52 46 36 53 04 00 00 00 00 06 65 64
61 36 33 30 06 00 00 00 00 0e 44 4a 49 20 4d 69 63 20 4d 69 6e 69 20
32 01 01 00 00 00 12 00 11 03 02 42 33 4d 54 50 33 4e 30 31 35 5a 58
4d 5a 04 01 00 00 00 06 61 66 62 30 36 64 06 01 00 00 00 0e 44 4a 49
20 4d 69 63 20 4d 69 6e 69 20 32 c8 c3
```

Decodifica para:

- RX `DJI Mic Mini 2`, fw `02.03.17.00`, sufixo `eda630`
- TX1 `DJI Mic Mini 2`, fw `02.03.17.00`, sufixo `afb06d`

### 6.3 Nível

Payload de 10 bytes:

```
55 17 04 38 5a 02 00 00 00 5b 03 03 07 00 05 01 00 00 00 01 1e 99 22
```

- `payload[0..2]` = `03 07 00`
- `payload[3] = 0x05` tag
- `payload[4] = 0x01` unidade
- `payload[9] = 0x1e` nível (30)

Slots de 7 bytes a partir de `payload[3]`.

### 6.4 Status completo de exemplo

```
55 56 04 67 5a 02 00 00 00 5b 03 03 46 00 03 00 00 00 00 20 00 01 06
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 01 00
00 00 3e 00 00 00 02 01 00 00 00 1a 38 24 04 89 00 78 00 00 00 00 00
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 bc 26
```

Este frame tem 1 TX. O slot em `payload[41]` começa em `02 01 00 00 00 1a
38 24 04 89 00 78 ...`.

## 7. Como montar e enviar

### 7.1 Python

Montar:

```python
from dji_protocol import build_command, ADDRESS_RX

packet = build_command(ADDRESS_RX, 0x0039, 6, 0x1234)
print(packet.hex(" "))
```

Enviar usando a CLI:

```bash
uv run python tools/poc/dji_probe.py set gain 6
uv run python tools/poc/dji_probe.py set voice-tone bright --tx 1
uv run python tools/poc/dji_probe.py set clipping-control on
uv run python tools/poc/dji_probe.py raw '55 16 04 fc ...'
```

O `set` já:

1. abre a interface 6;
2. monta o pacote com sequência;
3. escreve no endpoint `0x06`;
4. lê o endpoint `0x86`;
5. espera o ACK da sequência;
6. retorna código 3 se o ACK for `0xff`.

### 7.2 pyusb cru

Somente para laboratório; prefira a CLI:

```python
import usb.core, usb.util
from dji_protocol import build_command, ADDRESS_RX

dev = usb.core.find(idVendor=0x2CA3, idProduct=0x4011)
dev.set_configuration()
usb.util.claim_interface(dev, 6)

dev.write(0x06, build_command(ADDRESS_RX, 0x0039, 6, 0x1234), timeout=1000)
```

Em macOS, o `pyusb` pode precisar de `USBInterfaceOpenSeize`; o POC já trata
isso via libusb. O app nativo usa IOKit diretamente.

### 7.3 Swift

```swift
let session = MicSession()
session.start()
try await session.send(.gain(6))
```

Para um pacote cru:

```swift
let packet = MicSetting.gain(6).command.encoded(sequence: 0x1234)
try transport.write(Data(packet), timeout: 0.5)
```

### 7.4 App / sessão

O `MicSession`:

- abre a interface;
- lê continuamente;
- alimenta o `DUMLParser`;
- mantém `DeviceSnapshot`;
- resolve ACK por sequência;
- reconecta quando o cabo cai;
- deduplica snapshots idênticos.

## 8. Comandos validados

| Ajuste | Cmd | Target | Valor | Leitura |
|---|---|---|---|---|
| Gain | `0x0039` | RX | int8 | `payload[11]` |
| Monitoring gain | `0x0026` | RX | int8 | `payload[16]` |
| Safety track | `0x0021` | RX | 0/1 | `payload[37]` bit 6 |
| Mono/Stereo | `0x0008` | RX | 0 mono / 2 stereo | `payload[10]` bit 2 |
| Low cut | `0x0003` | broadcast | 0/1 | TX slot `+9` bit 5 |
| Mic LED | `0x000A` | broadcast | 0 on / 2 off | TX slot `+6` bit 1 |
| Voice tone | `0x0029` | TX1/TX2 | 0 regular / 1 rich / 2 bright | TX slot `+9` bits 6–7 |
| Clipping | `0x001E` ou `0x0024` | RX | 0/1 | RX `payload[37]` bit 4 e TX `+8` bit 2 |
| Auto-off TX | `0x0010` | broadcast | 0/1 | TX slot `+6` bit 4 |
| Auto-off RX | `0x0010` | RX | 0/1 | RX `payload[10]` bit 0 |
| NC on/off | `0x0038` | qualquer | — | **rejeitado** |
| NC Basic/Strong | `0x0037` | qualquer | — | **rejeitado** |

## 9. Método de descoberta de comandos novos

### 9.1 Teste diferencial

1. Abra `monitor --raw --jsonl captures/antes.jsonl`.
2. Capture 5–10 s de baseline.
3. Altere **um** ajuste (no app oficial, botão físico ou comando candidato).
4. Capture novamente.
5. Compare status byte a byte.
6. Confirme ACK e efeito físico.
7. Repita para reverter.

### 9.2 Comandos candidatos

- IDs vêm de referências públicas.
- Teste com target RX, TX1 e broadcast.
- Teste valores `0`/`1`/`2` e observe ACK.
- Um ACK `0xff` significa “não suportado/rejeitado”.
- Alguns comandos podem aceitar mas não mudar o status; confirme o efeito
  físico.

### 9.3 Captura do app oficial

Se o comando for desconhecido:

- captura USB com analisador de hardware ou Linux `usbmon` + Wireshark;
- alternativa: análise estática do app móvel;
- alternativa: teste diferencial no próprio hardware.

O projeto ainda não fez captura com analisador de hardware. O que temos é:
observação direta, referências públicas e teste diferencial.

## 10. Adicionar um comando ao código

Checklist:

1. Validar no POC com `raw`/`set`.
2. Registrar ACK e offsets em `feature-matrix.md`.
3. Adicionar o caso em `MicSetting` (`Sources/DJIMicProtocol/Settings.swift`).
4. Adicionar ao `SETTINGS` do POC (`tools/poc/dji_probe.py`).
5. Adicionar a leitura em `DUML.swift` se for um estado novo.
6. Adicionar à UI (`AppModel.send` + view + i18n).
7. Adicionar teste em `tests/DJIMicProtocolTests/` e teste de sessão se
   necessário.
8. Rodar `swift test` e `uv run python -m unittest discover -s tests`.
9. Validar no hardware.
10. Atualizar documentação.

## 11. Debug

### 11.1 POC Python

```bash
uv run python tools/poc/dji_probe.py scan
uv run python tools/poc/dji_probe.py status --raw
uv run python tools/poc/dji_probe.py monitor --levels --raw --jsonl captures/run.jsonl
```

Se der “device not found”:

- veja se o app está aberto (ele tem acesso exclusivo);
- confira o cabo;
- rode `ioreg -p IOUSB -l -w0 | grep -i 'Wireless Mic'`.

### 11.2 Swift probe

```bash
swift run djimic-swift-probe
swift run djimic-swift-probe --test-command
```

Ele imprime snapshots de conexão, identidade, TX, bateria e nível. O
`--test-command` envia um gain com o valor atual para validar o ACK.

### 11.3 App

```bash
./Scripts/build-app.sh
open Release/DJIMic.app
pgrep -fl DJIMicApp
lsof -p <pid> | grep -i iousb
ioreg -r -n 'IOUSBHostInterface@6' -l -w0 | grep UsbExclusiveOwner
log show --last 5m --predicate 'process == "DJIMicApp"' --style compact
```

### 11.4 UI sem tela

Os testes `tests/DJIMicUITests/RenderTests.swift` geram snapshots com
`NSHostingView` em light/dark/pt-BR. Isso valida layout sem precisar de
permissão de gravação de tela.

## 12. Segurança

Não enviar sem pesquisa:

- firmware update
- formatação de armazenamento interno
- reboot do RX (`0x0023`, plug-free speaker)
- comandos de factory reset
- comandos desconhecidos em massa/fuzzing

Cuidados:

- feche o app antes do POC;
- faça backup dos settings;
- reverta cada teste;
- não use `raw` em comandos de bootloader;
- não trate ACK `0x00` como prova de efeito físico.

## 13. Limitações conhecidas

- NC é read-only no Mic Mini 2.
- Bateria é gauge de 7 níveis.
- `0x20` (turn on with camera) não validado.
- `0x23` (plug-free) reinicia o RX.
- Frames `5b 04` ainda não decodificados.
- Apenas um TX foi testado; o parser suporta dois.
- Mute, RSSI, BLE battery, internal recording e pairing não foram descobertos.
- A interface 6 é exclusiva enquanto o app está aberto.

## 14. Referências

Ver [`references.md`](references.md). Resumo:

- `ShadowBitBasher/DJI-Mic-Control` — framing, ACK, interface 6.
- `usokawa/dji-mic-mo` — VID/PIDs, IDs de comandos, offsets.
- `usokawa/dji-mic-mo#1` — NC físico e ACK `0xff`.
- IOKit headers / libusb Darwin — `IOCreatePlugInInterfaceForService` retry e
  `USBInterfaceOpenSeize`.
- Observação direta do dispositivo.

Nenhum código foi copiado.
