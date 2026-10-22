# DJI Mic 2 — relatório de descoberta e testes de protocolo

Relatório do que foi investigado, testado e validado no hardware real em
2026-10-22. O plano vivo e as hipóteses ainda abertas ficam em
[`dji-mic-2-discovery-plan.md`](dji-mic-2-discovery-plan.md).

## 1. Hardware e firmware

| Item | Valor |
|---|---|
| Receptor USB | `Wireless Mic Rx`, `2ca3:4011` |
| Interface | 6 (`0xff/0xf0`), bulk OUT `0x06`, IN `0x86` |
| Protocolo | DUML v2, comandos de 22 bytes, ACK de 14 bytes |
| RX (protocolo) | `DJI Mic Mini 2`, firmware `02.03.17.00`, SN `B3NXNB4022RF6S`, sufixo `eda630` |
| TX1 | `DJI Mic 2`, firmware `04.05.02.31`, sufixo `85f8c8`, SN vazio |
| TX2 | `DJI Mic 2`, firmware `04.05.01.11`, sufixo `04b999`, SN vazio |
| App oficial | RX `DJI Mic Series–eda630`; TX `DJI Mic 2 TXn–sufixo` |

O RX responde ao protocolo do Mini 2, mas os transmissores são DJI Mic 2.
Isso explica parte das diferenças abaixo.

## 2. Método

1. App macOS fechado para liberar a interface 6.
2. Baseline com `scan`, `status --raw` e captura contínua.
3. **Diff com o app oficial**: uma opção por vez no celular, comparando os
   bytes de status antes/depois. Isso revelou bits de mute, gravação,
   vibração etc. sem enviar comandos desconhecidos.
4. **Teste de candidatos**: comandos conhecidos/hipóteses, um por vez, com
   ACK `0x00`, mudança de status e reversão.
5. Estado restaurado ao final de cada teste.

## 3. Inventário das telas do app oficial

### Wireless Mic

- Gain RX (`-12…+12`).
- Noise Reduction: `Disable / Basic / Strong`.
  - Nota do app: “DJI Mic 2 only supports enabling or disabling noise
    cancellation”.
  - Controla o NC de todos os transmissores.
- TX cards: nome + sufixo, bateria, **mute**, **REC**, canal `L/R`,
  medidor de nível, **Format** (`11.2h/11.2h`).

### RX Settings

- Audio Channel: `Mono / Stereo`.
- Safety Track (nota: só disponível em Mono).
- Gain Control com 5 detentes.
- Monitoring Gain (`-12…+12`).
- Noise Reduction.

### More Settings

- Audio: Low Cut, Clipping Control.
- Internal Recording: 32-Bit Float Recording, Startup Auto Recording.
- Buttons & LED: REC Stop Lock, Vibration, Mic LED.
- General: Auto Off (TX desliga após 15 min sem uso/conexão/gravação).

## 4. Matriz: temos × falta

| Função | Nosso app | DJI Mic 2 | Observação |
|---|---|---|---|
| Gain RX | ✅ | ✅ `0x0039` | validado |
| Monitoring Gain | ✅ | provável `0x0026` | não retestado nesta sessão |
| Audio Channel | ✅ | ✅ `0x0008` | validado |
| Safety Track | ✅ | ✅ `0x0021` | falta regra “só Mono” na UI |
| Noise Reduction | ⚠️ só leitura | ❌ comando rejeitado | limitação do RX Mini 2 |
| Low Cut | ✅ | ✅ `0x0003` | broadcast |
| Clipping Control | ✅ | ✅ `0x001E` | validado |
| Auto Off TX | ✅ | ✅ `0x0010` | broadcast |
| Auto Off RX | ✅ | ✅ no Mini 2 | Mic 2 não retestado |
| Mic LED | ✅ | ⚠️ target por unidade age como broadcast | validado por status |
| Voice Tone | ✅ | ⚠️ ACK sem mudança de status | áudio não confirmado |
| Find TX | ✅ | ⚠️ afeta os dois TXs | target por unidade não isola |
| **Mute** | ❌ | ✅ `0x0009` por TX | novo |
| **REC start/stop** | ❌ | ✅ `0x0002` por TX | novo |
| **Vibração** | ❌ | ✅ `0x0004` broadcast | novo |
| **32-bit float** | ❌ | ✅ `0x000C` broadcast | novo |
| **REC Stop Lock** | ❌ | ✅ `0x000B` broadcast | novo |
| **Startup Auto Recording** | ❌ | ✅ `0x002E` broadcast | novo |
| **Tempo de gravação** | ❌ | ✅ leitura `+14/+16` | novo |
| Bateria TX | ✅ | ✅ | gauge de 7 níveis |
| Nome + sufixo | ✅ | ✅ | TX sem SN no protocolo |

## 5. Comandos validados no DJI Mic 2

| Função | Comando | Target | Escopo | Status | Evidência |
|---|---|---|---|---|---|
| Mute | `0x0009` | TX1/TX2 | por unidade | `+6` bit `0x04` | muta/desmuta só o TX alvo |
| REC | `0x0002` | TX1/TX2 | por unidade | `+9` bit `0x10` | grava só o TX alvo |
| Vibração | `0x0004` | broadcast | todos | `+9` bit `0x01` | TX1/TX2 mudam juntos |
| 32-bit float | `0x000C` | broadcast | todos | `+9` bit `0x08` | tempo 11.2h ↔ 15.0h |
| REC Stop Lock | `0x000B` | broadcast | todos | `+11` bit `0x20` | TX1/TX2 mudam juntos |
| Startup Auto Rec | `0x002E` | broadcast | todos | `+8` bit `0x80` | TX1/TX2 mudam juntos |

Todos os testes tiveram ACK `0x00` e foram revertidos ao estado original.
`0x0002` e `0x0009` são os únicos **por unidade**; os demais são broadcast
mesmo quando o target é TX1.

## 6. Status do TX — offsets confirmados

Slot de 32 bytes, começando em `payload[41]`:

| Campo | Offset | Formato |
|---|---|---|
| LEDs desligados | `+6` bit `0x02` | bool |
| **Mute** | `+6` bit `0x04` | bool |
| Vibração | `+9` bit `0x01` | bool |
| **32-bit float** | `+9` bit `0x08` | bool |
| **Gravando** | `+9` bit `0x10` | bool |
| Low cut | `+9` bit `0x20` | bool |
| Voice tone | `+9` bits `0x40/0x80` | regular/rich/bright |
| **Startup Auto Rec** | `+8` bit `0x80` | bool |
| **REC Stop Lock** | `+11` bit `0x20` | bool |
| **Tempo total** | `+14` | uint16 LE ÷ 10 (horas) |
| **Tempo restante** | `+16` | uint16 LE ÷ 10 (horas) |
| Bateria | `+7` bits `0x1c` | 1 cheio … 7 vazio |
| Charging | `+7` bit `0x02` | bool |
| Clipping | `+8` bit `0x04` | bool |

Exemplo real (TX1, 32-bit float ligado):

```text
+8=00 +9=28 +11=58 +13=fd +14/+16=70 00/70 00  ->  11.2h/11.2h
```

Com 32-bit float desligado, `+9` vira `0x20` e `+14/+16` viram `96 00`
(`15.0h`). Isso confirma a semântica do tempo e do bit.

## 7. NC (noise reduction) — bloqueado neste RX

Tentativas no Mic 2:

| Comando | Target | Valor | ACK |
|---|---|---|---|
| `0x0038` | RX `0x0000` | `0` | `0xff` |
| `0x0038` | broadcast `0xFFFF` | `0` | `0xff` |
| `0x0038` | TX1 `0x0001` | `0` | `0xff` |
| `0x0037`, `0x0036`, `0x003A` | RX | `0` | `0xff` |

Conclusão: a escrita de NC é rejeitada pelo RX, que se identifica como Mini
2. A limitação parece ser do receptor, não dos TXs Mic 2. O app oficial
consegue controlar NC provavelmente por outro caminho (Bluetooth/telefone).

## 8. Outras diferenças observadas

- **Serial do TX**: o frame de identidade tem o campo de 14 bytes, mas vem
  preenchido com `0x00`. O app oficial também mostra `—`.
- **Nome do RX**: o firmware reporta `DJI Mic Mini 2`; o app oficial usa
  `DJI Mic Series–<sufixo>`. O app macOS agora segue o padrão do oficial e
  mostra o valor cru como “Protocol name” no diagnóstico.
- **Mic LED / Find**: `0x000A` com target TX1 afeta os dois TXs.
- **Voice tone**: ACK `0x00`, mas o status não muda; não validado.
- **Ganho do TX**: `0x0039` com target TX1 deu ACK, mas `+13` não mudou;
  não validado.

## 9. CLI Python — novos comandos

O POC agora expõe:

```bash
uv run python tools/poc/dji_probe.py set mute on --tx 1
uv run python tools/poc/dji_probe.py set mute off --tx 1

uv run python tools/poc/dji_probe.py set rec on --tx 1
uv run python tools/poc/dji_probe.py set rec off --tx 1

uv run python tools/poc/dji_probe.py set vibration on
uv run python tools/poc/dji_probe.py set vibration off

uv run python tools/poc/dji_probe.py set float32 on
uv run python tools/poc/dji_probe.py set float32 off

uv run python tools/poc/dji_probe.py set rec-stop-lock on
uv run python tools/poc/dji_probe.py set rec-stop-lock off

uv run python tools/poc/dji_probe.py set startup-auto-recording on
uv run python tools/poc/dji_probe.py set startup-auto-recording off
```

`status` e `monitor` agora mostram `mute`, `rec`, `float32`, `vib`, `time`
e os demais campos do slot do TX.

Teste real do CLI: `set mute on --tx 1` → ACK ok, `status` mostrou
`tx1 muted=True, tx2 muted=False`; `mute off` restaurou.

## 10. Estado ao final dos testes

- Mute: TX1 e TX2 **desmutados**.
- REC: parado.
- Vibração: desligada (estado inicial do USB).
- 32-bit float: ligado (11.2h/11.2h).
- REC Stop Lock: desligado.
- Startup Auto Recording: desligado.
- NC: ligado.
- Um arquivo curto de gravação foi criado no TX1 durante o teste de REC.

## 11. Pendências

1. NC: confirmar se é limitação do RX Mini 2 ou achar o caminho alternativo.
2. Ganho do TX (`0x0039` target TX): investigar encoding/offset.
3. Voice tone no Mic 2: confirmar por áudio/offset.
4. Implementar no app Swift: mute, REC, vibração, 32-bit float,
   startup auto recording, REC stop lock e tempo de gravação.
5. Avaliar o Find por unidade no Mic 2 (hoje afeta os dois TXs).

## 12. Implementação no app Swift

Implementado em `main`:

- **Perfis por componente**: `DeviceFamily`, `DeviceCapabilities`,
  `DeviceProfile`, `DeviceSystemProfile` e `DeviceProfileResolver`.
  - Regra de família usa apenas `productName` com os nomes completos
    `DJI Mic Mini 2` e `DJI Mic 2`; sem fallback por firmware.
  - O kit híbrido resolve para RX Mini 2 + TX Mic 2.
- **Comandos com escopo**: `CommandSpec` (`receiver` / `broadcast` /
  `unit`) e `MicSetting.command(for:)`; `MicSession.send` recusa ajuste
  não suportado (`unsupportedSetting`).
- **Parser por layout**: `DUMLParser` recebe `StatusLayout` (`.common` ou
  `.mic2`); os campos novos do TX são lidos só no layout Mic 2.
- **Estado**: `TransmitterState` ganhou `isMuted`, `isRecording`,
  `vibrationEnabled`, `float32Recording`, `recStopLock`,
  `startupAutoRecording`, `recordingTimeTotal`, `recordingTimeRemaining`.
- **UI**:
  - Card do TX Mic 2 mostra **Recording** (REC) e tempo `11.2h / 11.2h`;
    o botão de **mute** fica no rodapé, ao lado do Find.
  - “Mais ajustes” ganhou a seção **Internal Recording** com Vibração,
    32-Bit Float, Startup Auto Recording e REC Stop Lock.
  - Voice tone fica oculto no Mic 2 até confirmação do efeito.
  - Safety Track fica desabilitado em Stereo, com nota “Only available in
    Mono mode”.
- **Optimistic update/reconciliação** cobre mute, REC, vibração, 32-bit,
  REC lock e startup.
- **Testes**: perfis híbridos, regra de família, targets de comando,
  parsing dos campos Mic 2 e render da UI; 13 testes de protocolo e 20 de
  UI passando.

