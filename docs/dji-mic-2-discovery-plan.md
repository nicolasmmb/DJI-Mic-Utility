# DJI Mic 2 — descoberta de funções e compatibilidade de protocolo

Documento de trabalho para descobrir as funções exclusivas do **DJI Mic 2** e
medir o que do protocolo atual (validado no Mic Mini 2) é reaproveitável.

Data de início: 2026-10-22.

## 1. Contexto observado

| Item | Valor |
|---|---|
| Receptor USB | `Wireless Mic Rx`, `2ca3:4011` |
| Interface de controle | 6 (`0xff/0xf0`), bulk `0x06`/`0x86` |
| Protocolo | DUML v2 |
| RX reportado | `DJI Mic Mini 2`, firmware `02.03.17.00`, SN `B3NXNB4022RF6S`, sufixo `eda630` |
| TX1 | `DJI Mic 2`, firmware `04.05.02.31`, sufixo `85f8c8`, SN vazio |
| TX2 | `DJI Mic 2`, firmware `04.05.01.11`, sufixo `04b999`, SN vazio |
| App oficial | mostra RX como `DJI Mic Series–eda630` e TX como `DJI Mic 2 TXn–<sufixo>` |

O RX e os TXs são de gerações diferentes: o RX responde ao protocolo do
Mini 2, mas os transmissores são Mic 2 (firmware `04.05.x`). O app oficial
expõe funções que o app macOS ainda não controla.

## 2. Inventário das telas do app oficial

### 2.1 Wireless Mic (RX + TX)

- Gain RX: `-12…+12`.
- Noise Reduction: `Disable / Basic / Strong`.
  - Nota: “DJI Mic 2 only supports enabling or disabling noise cancellation”.
  - Nota: controla o NC de todos os transmitters.
- TX Settings:
  - Nome + sufixo, bateria, **mute**, **REC**.
  - Canal `L/R` com medidor de nível.
  - **Format**: `11.2h/11.2h` (tempo de gravação interna).

### 2.2 RX Settings

- Audio Channel: `Mono / Stereo`.
- Safety Track, com nota: “Only available in Mono mode. Use post-production
  software and separate audio tracks later”.
- Gain Control: 5 detentes (`-12`, `-6`, `0`, `+6`, `+12`).
- Monitoring Gain: slider `-12…+12`.
- Noise Reduction: mesma tríade com a mesma nota.

### 2.3 More Settings

- **Audio Settings**: Low Cut, Clipping Control.
- **Internal Recording Settings**:
  - 32-Bit Float Recording.
  - Startup Auto Recording.
- **Buttons & LED Indicators**:
  - REC Stop Lock.
  - Vibration.
  - Mic LED.
- **General**:
  - Auto Off (TX desliga após 15 min sem conexão/gravação/operação).

## 3. Matriz: temos × falta

| Função | Onde | Nosso app | DJI Mic 2 | Próximo passo |
|---|---|---|---|---|
| Gain RX | RX | ✅ | ✅ validado (`0x0039`) | — |
| Monitoring Gain | RX | ✅ | provável (`0x0026`), não testado | validar |
| Audio Channel | RX | ✅ | ✅ validado (`0x0008`) | — |
| Safety Track | RX | ✅ | ✅ validado (`0x0021`) | aplicar regra “só Mono” |
| Noise Reduction | RX/TX | ⚠️ só leitura | ❌ comando desconhecido; oficial escreve on/off | descobrir escrita |
| Low Cut | More | ✅ | ✅ validado (`0x0003` broadcast) | — |
| Clipping Control | More | ✅ | ✅ validado (`0x001E`) | — |
| Auto Off TX | More | ✅ | ✅ validado (`0x0010` broadcast) | — |
| Auto Off RX | More | ✅ | ✅ no Mini 2; Mic 2 não testado | validar |
| Mic LED | More | ✅ | ✅, mas target por unidade vira broadcast | decidir UX do Find |
| Voice Tone | TX | ✅ | ⚠️ ACK `0x0029`, sem mudança de status | confirmar áudio/offset |
| Find TX | TX | ✅ | ⚠️ `0x000A` por unidade afeta os dois TXs | investigar alternativas |
| Mute por TX | TX card | ❌ | ✅ `0x0009` **por unidade**; `+6` bit `0x04` | implementar |
| REC start/stop por TX | TX card | ❌ | ✅ `0x0002` **por unidade**; `+9` bit `0x10` | implementar |
| 32-Bit Float Recording | More | ❌ | ✅ `0x000C` broadcast; `+9` bit `0x08` | implementar |
| Startup Auto Recording | More | ❌ | ✅ `0x002E` broadcast; `+8` bit `0x80` | implementar |
| REC Stop Lock | More | ❌ | ✅ `0x000B` broadcast; `+11` bit `0x20` | implementar |
| Vibration | More | ❌ | ✅ `0x0004` broadcast; `+9` bit `0x01` | implementar |
| Format / tempo de gravação | TX card | ❌ | ✅ leitura `+14/+16` (h ×10) | implementar |
| L/R por TX | TX card | ⚠️ parcial (mono/stereo global) | provavelmente fixo | mapear em stereo |
| Bateria TX | TX card | ✅ | ✅ | — |
| Nome + sufixo RX/TX | header/diag | ✅ | ✅; TX sem SN no protocolo | — |
| Ícone de status do RX | RX card | ❓ | desconhecido | identificar no status |

## 4. Compatibilidade de comandos já testada

Testes feitos no hardware real, com ACK `0x00` e restauração do estado
original:

| Comando | Mini 2 | DJI Mic 2 | Evidência |
|---|---|---|---|
| `0x0039` Gain | ✅ | ✅ | status `payload[11]` mudou e voltou |
| `0x0026` Monitoring | ✅ | não testado | — |
| `0x0008` Stereo | ✅ | ✅ | `payload[10]` bit 2 |
| `0x0021` Safety | ✅ | ✅ | `payload[37]` bit 6 |
| `0x001E` Clipping | ✅ | ✅ | RX bit 4 + TX `+8` bit 2 |
| `0x0003` Low cut | ✅ | ✅ | TX `+9` bit 5 nos dois |
| `0x0010` Auto-off TX | ✅ | ✅ | TX `+6` bit 4 nos dois |
| `0x0010` Auto-off RX | ✅ | não testado | — |
| `0x000A` Mic LED | broadcast ✅; por unidade não validado | ACK por unidade, mas afeta os dois TXs | status `leds_off` |
| `0x0029` Voice tone | ✅ | ⚠️ ACK, sem mudança de status | áudio não confirmado |
| `0x0004` Vibration | — | ✅ broadcast; `+9` bit `0x01` | ACK + status |
| `0x000C` 32-bit float | — | ✅ broadcast; `+9` bit `0x08`; tempo 11.2h ↔ 15.0h | ACK + status + tempo |
| `0x000B` REC Stop Lock | — | ✅ broadcast; `+11` bit `0x20` | ACK + status |
| `0x002E` Startup Auto Rec | — | ✅ broadcast; `+8` bit `0x80` | ACK + status |
| `0x0002` REC start/stop | — | ✅ **por unidade**; `+9` bit `0x10` | ACK + status; TX2 não muda |
| `0x0009` Mute | — | ✅ **por unidade**; `+6` bit `0x04` | ACK + status; TX2 não muda |
| `0x0038` / `0x0037` NC | ❌ rejeitado | ❌ rejeitado neste RX | limitação do RX Mini 2 |
| Mute / REC / vibração / 32-bit / rec lock | não descoberto | não descoberto | — |

## 5. Offsets conhecidos

### Status (105 bytes com 2 TXs)

- RX: gain `11`, monitoring `16`, flags `9/10/37`.
- TX: slots de 32 bytes a partir de `41`.
  - `+6`: LEDs, auto-off, NC strong, NC via botão.
  - `+7`: bateria/charging/NC on.
  - `+8`: clipping.
  - `+9`: low cut / voice tone.

### Identidade (161 bytes com 2 TXs)

- RX: serial `13…26`, firmware `9…12`, sufixo `33…38`, nome `45…`.
- TX: registros de `42 + tamanhoDoNome` a partir de `45 + payload[44]`.
  - `+6`: firmware (reverso).
  - `+10…+23`: serial (vem `0x00` no Mic 2).
  - `+30…+35`: sufixo.
  - `+41`: tamanho do nome; `+42…`: nome.

## 6. Plano de descoberta

### Fase 0 — preparação e baseline

1. Fechar o app macOS (interface 6 exclusiva).
2. `scan`, `status --raw`, identidade crua.
3. Capturar `monitor --levels --raw --jsonl captures/djimic2-base.jsonl`.
4. Registrar estado de todos os ajustes conhecidos para restauração.

### Fase 1 — mapeamento diferencial (sem enviar comandos)

Para cada opção do app oficial: NC, mute TX1/TX2, REC, 32-bit float,
startup auto recording, REC stop lock, vibration, format/tempo.

1. Capturar 8 s de baseline.
2. Alterar **uma** opção no app oficial.
3. Capturar 8 s.
4. Comparar status/identity e listar offsets/bits alterados.
5. Reverter e repetir.

Ferramenta: `monitor --levels --raw --jsonl` + script de diff (a criar em
`tools/poc/`). Saída esperada: offset, máscara, antes/depois.

### Fase 2 — descobrir comandos de escrita

Sempre um candidato por vez, ACK `0x00`, status e efeito físico; reverter.

1. **NC**: `0x0038` valores `0/1/2`, targets RX (`0x0000`) e broadcast
   (`0xFFFF`); `0x0037` para “Strong”. Validar `flags9` bits `0x20/0x08`.
2. **Mute**: candidatos próximos de `0x0003`, `0x0008`, `0x000A`, `0x0010`,
   `0x0021`, `0x0026`, `0x0029`, `0x0039`; validar ACK, bit no slot TX e
   queda de RMS > 20 dB no áudio USB.
3. **REC**: candidatos na mesma faixa; validar ACK, LED/estado de gravação e
   status.
4. **32-bit / startup / rec lock / vibration**: primeiro achar o estado pela
   Fase 1; depois testar candidatos de escrita.
5. **Format/tempo**: capturar antes/durante/depois de uma gravação curta;
   localizar contadores e unidades.

### Fase 3 — promoção

1. Documentar comando, target, valor, offset, firmware e evidência.
2. Adicionar ao POC.
3. Atualizar `docs/protocol-notes.md` e `docs/feature-matrix.md`.
4. Implementar `MicSetting` + UI Swift somente após validação.
5. Adicionar testes de protocolo e de UI.

## 7. Segurança

- Não enviar firmware, formatação, factory reset, reboot ou bootloader.
- Não testar `0x0023` (reinicia o RX) nem `0x0020` sem pesquisa.
- Uma variável por vez; reverter sempre.
- Parar em ACK `0xff`, timeout ou comportamento anormal.
- Gravações internas podem criar arquivos no TX: confirmar com o usuário
  antes de iniciar.
- Não deixar o TX em estado estranho; se necessário, reconectar o USB.

## 8. Critérios de aceite

Uma função só entra no app quando tiver:

1. ACK `0x00` consistente;
2. mudança de status reproduzível;
3. efeito físico/áudio reproduzível;
4. reversão confirmada;
5. comando, target, valor e offset documentados;
6. teste automatizado no POC/Swift.

## 9. Registro de sessões

### 2026-10-22 — compatibilidade inicial

- Confirmado mesmo USB e mesmo DUML v2.
- Validados no Mic 2: gain, stereo, safety, clipping, low cut, auto-off TX.
- Mic LED por unidade: ACK, mas os dois TXs mudam.
- Voice tone: ACK, sem mudança de status.
- Serial dos TXs não é enviado (oficial mostra `—`).
- Identidade do RX reporta `DJI Mic Mini 2`; app oficial usa
  `DJI Mic Series–<sufixo>`.

## 10. Hipóteses vindas das referências públicas

Fonte: tabela de configuração do projeto `usokawa/dji-mic-mo` (consultada como
referência de fatos do protocolo; nenhum código foi copiado para o repo).

Esses IDs/offsets ainda **não** são fatos no nosso hardware; entram como
hipóteses a validar com ACK + status + efeito físico.

### 10.1 Leitura no slot do TX (status)

| Campo | Offset/expressão | Valor esperado |
|---|---|---|
| `recordingTimeTotal` | `+14`, uint16 LE ÷ 10 | `11.2` |
| `recordingTimeRemaining` | `+16`, uint16 LE ÷ 10 | `11.2` |
| `rec` | `+9` bit `0x10` | gravando |
| `float32Recording` | `+9` bit `0x08` | 32-bit float ligado |
| `vibration` | `+9` bit `0x01` | vibração ligada |
| `recStop` (lock) | `+11` bit `0x20` | REC Stop Lock ligado |
| `startupAutoRecording` | `+8` bit `0x80` | auto-recording no boot |
| `fileOptionEditedFile` | `+31` bit `0x80` | arquivo editado |
| `transmitterGain` | `+13`, int8 | ganho do TX |

Conferência rápida com o slot atual (TX1):

```
02 01 00 00 00 1a 10 2c 00 28 00 58 00 fd 70 00 70 00 ...
                              ^^ ^^    ^^    ^^
                              +9 +11   +13   +14/+16
```

- `+14`/`+16` = `70 00`/`70 00` → `11.2h/11.2h` (bate com o app oficial).
- `+9` = `0x28` → float32 ligado (bit `0x08`) e low cut ligado.
- `+11` = `0x58` → REC Stop Lock desligado (bit `0x20` = 0).
- `+8` = `0x00` → startup auto recording desligado.
- `+13` = `0xfd` → `-3` (ganho do TX, a confirmar).
- `+9` bit `0x01` = 0 → vibração desligada no status, embora o app
  oficial mostre ligada; validar em tempo real.

### 10.2 Comandos candidatos

| Função | Comando | Target | Valor |
|---|---|---|---|
| REC start/stop | `0x0002` | TX1/TX2 | `1`/`0` |
| Vibração | `0x0004` | TX1/TX2 | `1`/`0` |
| REC Stop Lock | `0x000B` | TX1/TX2 | `1`/`0` |
| 32-bit float | `0x000C` | TX1/TX2 | `1`/`0` |
| Startup Auto Recording | `0x002E` | TX1/TX2 | `1`/`0` |
| Loop recording | `0x002A` | TX1/TX2 | `1`/`0` |
| Low-power auto recording | `0x002B` | TX1/TX2 | `1`/`0` |
| File option (edited file) | `0x003D` | TX1/TX2 | `2`/`0` |
| Ganho do TX | `0x0039` | TX1/TX2 | int8 |
| NC on/off | `0x0038` | broadcast | `1`/`0` |
| NC strong | `0x0037` | broadcast | `1`/`0` |

Observações:

- `0x0038` e `0x0037` foram **rejeitados** neste RX (`0xff`), consistente com
  a referência que marca NC como não suportado no Mini 2. O RX deste kit
  reporta Mini 2; pode ser limitação do RX, não dos TXs.
- Mute por TX não aparece na tabela da referência; segue desconhecido.
- REC Stop Lock do app oficial provavelmente é o `0x000B`; validar.

### 10.3 Próximos testes (ordem)

1. Vibração `0x0004` TX1: off → on, conferir `+9` bit `0x01`, restaurar.
2. 32-bit float `0x000C` TX1: off → on, conferir `+9` bit `0x08`, restaurar.
3. REC Stop Lock `0x000B` TX1: on → off, conferir `+11` bit `0x20`, restaurar.
4. Startup Auto Recording `0x002E` TX1: on → off, conferir `+8` bit `0x80`,
   restaurar.
5. REC `0x0002` TX1: iniciar/parar uma gravação curta (somente com
   confirmação explícita), conferir `+9` bit `0x10` e o tempo em `+14/+16`.
6. Mute: continuar por diff com o app oficial / candidatos.
7. NC: confirmar se a limitação é do RX Mini 2; testar targets TX1/TX2.

### 2026-10-22 — sessão de descoberta NC

- `0x0038` target RX (`0x0000`) valor `0` → ACK `0xff` (rejeitado).
- `0x0038` target broadcast (`0xFFFF`) valor `0` → ACK `0xff`.
- `0x0037`, `0x0036`, `0x003A` target RX valor `0` → ACK `0xff`.
- NC permaneceu ligado (`flags9 = 0x20`).
- Conclusão parcial: este RX (que se identifica como Mini 2) rejeita a
  escrita de NC; a limitação parece ser do RX, não dos TXs Mic 2.

### 2026-10-22 — comandos de gravação e botões (validados)

Baseline do slot TX1: `+8=00`, `+9=28`, `+11=58`, `+13=fd`,
`+14/+16=70 00/70 00` (11.2h/11.2h).

| Teste | Comando | Target | Valor | ACK | Status | Revertido |
|---|---|---|---|---|---|---|
| Vibração on | `0x0004` | TX1 | `1` | `0x00` | `+9` bit `0x01` nos 2 TXs | ✅ |
| Vibração off | `0x0004` | TX1 | `0` | `0x00` | bit volta a 0 | ✅ |
| 32-bit float off | `0x000C` | TX1 | `0` | `0x00` | `+9` bit `0x08` = 0 nos 2 TXs; tempo `70 00` → `96 00` (11.2h → 15.0h) | ✅ |
| 32-bit float on | `0x000C` | TX1 | `1` | `0x00` | bit volta; tempo volta a 11.2h | ✅ |
| REC Stop Lock on | `0x000B` | TX1 | `1` | `0x00` | `+11` bit `0x20` nos 2 TXs | ✅ |
| REC Stop Lock off | `0x000B` | TX1 | `0` | `0x00` | bit volta a 0 | ✅ |
| Startup auto rec on | `0x002E` | TX1 | `1` | `0x00` | `+8` bit `0x80` nos 2 TXs | ✅ |
| Startup auto rec off | `0x002E` | TX1 | `0` | `0x00` | bit volta a 0 | ✅ |

Conclusões:

- Os comandos `0x0004`, `0x000C`, `0x000B` e `0x002E` funcionam no DJI Mic 2
  e são **broadcast** (target TX1 altera os dois TXs).
- `+14` e `+16` são tempo total/restante de gravação em horas ×10
  (uint16 LE).
- `+9` bit `0x08` = 32-bit float; `+9` bit `0x01` = vibração;
  `+11` bit `0x20` = REC Stop Lock; `+8` bit `0x80` = Startup Auto
  Recording.
- A queda de tempo de 15.0h para 11.2h ao ligar 32-bit float confirma a
  semântica do campo.

Pendentes nesta sessão:

- REC start/stop (`0x0002`) — cria arquivo interno; precisa de confirmação.
- Mute por TX — comando desconhecido; precisa de diff com o app oficial.
- NC — bloqueado no RX Mini 2.
- `0x002A` loop, `0x002B` low-power, `0x003D` file option e `0x0039` ganho
  do TX — hipóteses ainda não testadas.

### 2026-10-22 — REC por unidade (validado)

Baseline: TX1/TX2 `rec_bit=False`, `+9=0x28`, tempo `11.2h/11.2h`.

| Teste | Comando | Target | Valor | ACK | Status |
|---|---|---|---|---|---|
| Iniciar REC TX1 | `0x0002` | TX1 | `1` | `0x00` | TX1 `+9=0x38` (bit `0x10`); TX2 permanece `0x28` |
| Parar REC TX1 | `0x0002` | TX1 | `0` | `0x00` | TX1 volta a `+9=0x28` |

Conclusões:

- `0x0002` é **por unidade** (target honrado); diferente de vibração,
  32-bit float, REC stop lock e startup auto recording, que são broadcast.
- O bit de gravação é `+9` bit `0x10`; a gravação foi iniciada e parada.
- Um arquivo curto foi criado no TX1 (gravação interna).

### 2026-10-22 — Mute por unidade (validado)

Método: com o app oficial, mutei o TX1 e comparei o status antes/depois.

- Antes: TX1 slot `+6 = 0x10`; TX2 `+6 = 0x10`.
- Depois do mute no app oficial: TX1 `+6 = 0x14` (bit `0x04`), TX2
  inalterado.
- Ou seja: o bit de mute é `+6` bit `0x04`, por TX.

Busca do comando (target TX1, valor `0` para desmutar):

| Comando | ACK | Efeito |
|---|---|---|
| `0x0005` | `0x00` | nenhum byte mudou |
| `0x0006` | `0xff` | rejeitado |
| `0x0007` | `0x00` | nenhum byte mudou |
| `0x0009` | `0x00` | TX1 `+6` `0x14 → 0x10` (desmutou) |

Validação completa:

| Ação | Target | Valor | ACK | Status |
|---|---|---|---|---|
| Mutar TX1 | TX1 | `1` | `0x00` | TX1 `+6=0x14`; TX2 `0x10` |
| Desmutar TX1 | TX1 | `0` | `0x00` | TX1 `+6=0x10` |
| Mutar TX2 | TX2 | `1` | `0x00` | TX2 `+6=0x14`; TX1 `0x10` |
| Desmutar TX2 | TX2 | `0` | `0x00` | TX2 `+6=0x10` |

Conclusão: **mute = `0x0009`, target por unidade, status TX `+6` bit
`0x04`**. É por unidade, como REC; os dois foram restaurados para
“desmutado”.

### 2026-10-22 — NC e ganho do TX (inconclusivos)

- `0x0038` target TX1 valor `0` → ACK `0xff` (rejeitado).
- `0x0039` target TX1 valor `0` e `253` → ACK `0x00`, mas o byte `+13`
  permaneceu `0xfd` (-3) nos dois casos. O comando não alterou o campo
  esperado; **ganho do TX não validado**.

### Pendências para a próxima sessão

1. **NC**: confirmar se a limitação é do RX Mini 2; testar targets TX1/TX2.
2. **Ganho do TX (`0x0039` target TX)**: comando ACKed mas `+13` não mudou;
   investigar encoding/offset ou descartar.
3. Implementar no Swift somente depois da validação: mute, REC, vibração,
   32-bit float, startup auto recording, REC stop lock e tempo de gravação.

