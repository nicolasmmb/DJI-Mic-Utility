# Contexto do projeto — reverse-dji-mic

Documento de continuidade. Um novo chat deve conseguir entender o que foi
feito, por que foi feito assim e como continuar sem redescobrir o protocolo.

## 1. Objetivo

Criar um app macOS simples e nativo para controlar o receptor USB-C de um kit
DJI Mic Mini 2 sem depender do app oficial de celular.

Objetivos secundários:

- entender e documentar o protocolo USB usado pelo receptor;
- validar comandos no hardware real antes de colocá-los na UI;
- manter uma implementação própria, sem importar código de projetos prontos;
- preservar o POC Python como ferramenta de laboratório;
- permitir que novos chats retomem o trabalho com contexto completo.

## 2. Hardware observado

| Item | Valor |
|---|---|
| Receptor | `Wireless Mic Rx` |
| VID:PID | `0x2ca3:0x4011` |
| Serial USB reportado | `XSP12345678B` (placeholder do descritor) |
| Produto no protocolo | `DJI Mic Mini 2` |
| Firmware | `02.03.17.00` |
| Sufixo de endereço RX | `eda630` |
| Transmissor | `DJI Mic Mini 2` |
| Firmware TX | `02.03.17.00` |
| Sufixo de endereço TX1 | `afb06d` |
| Áudio | entrada USB de 2 canais, 48 kHz, aparece como “Wireless Mic Rx” |

O receptor tem uma chave física **O/L/H** para Off/Basic/Strong de redução de
ruído. O protocolo não permite escrever esse estado neste kit.

O áudio USB continua funcionando mesmo com o app controlando a interface 6.
Isso foi verificado com `system_profiler SPAudioDataType`.

## 3. Topologia da comunicação

```
macOS / app
   │  USB bulk
   ▼
RX (interface 6)
   │  2.4 GHz
   ▼
TX1 / TX2
```

Não existe USB direto no transmissor. O RX é a ponte: o host envia comandos
para o RX e o RX os encaminha ao(s) TX(s). O estado do TX chega de volta nos
pushes de status do RX.

## 4. Descritores USB

| Interface | Classe | Uso |
|---|---|---|
| 0 | HID | Botões/consumer control; **não** é o canal de configuração |
| 1 | USB Audio control | Controle de áudio |
| 3 | USB Audio streaming | Entrada de áudio (isoc) |
| 6 | Vendor (`0xff/0xf0`) | **Canal de configuração e telemetria** |

Interface 6:

- Bulk OUT `0x06`
- Bulk IN `0x86`
- 2 endpoints
- No `ioreg`, aparece com `SupportsIAP = Yes` e é aberta pelo `accessoryd`.
- O app nativo usa `USBInterfaceOpenSeize` para assumir a interface.
- Enquanto o app está aberto, o POC Python não consegue abrir a mesma
  interface.

## 5. Histórico do trabalho

### 5.1 Reconhecimento inicial

1. Listagem dos dispositivos USB e identificação do RX.
2. Descoberta de que a interface 6 é vendor-specific e tem endpoints bulk.
3. Confirmação de que a interface 0 é HID e não serve para configurar o mic.
4. Verificação do áudio USB e do descritor de identidade.

### 5.2 Pesquisa de referências

Foram consultados apenas como informação:

- `ShadowBitBasher/DJI-Mic-Control` — mesmo VID/PID, documentação do framing
  DUML e semântica de ACK.
- `usokawa/dji-mic-mo` — WebUSB/Python, IDs de comandos e offsets de status.
- Issue `usokawa/dji-mic-mo#1` — confirmação do comportamento do Mic Mini 2:
  chave física de NC, rejeição de `0x37`/`0x38`, byte de resultado do ACK.

Nenhum código, arquivo, binário ou submódulo desses projetos foi incorporado.

### 5.3 Decisão de arquitetura

- POC em Python primeiro, para iterar rápido no protocolo.
- Depois, implementação Swift nativa.
- O POC Python continua no repositório como ferramenta de laboratório.
- O app não depende do Python.
- Sem bibliotecas de terceiros no app; IOKit nativo via shim C.
- Interface modular: protocolo puro, transporte, sessão, UI e composição.

### 5.4 Validação no hardware

Comandos testados com ACK + mudança no status:

- gain
- monitoring gain
- safety track
- mono/stereo
- low cut
- mic LED
- voice tone
- clipping (`0x1e` e alias `0x24`)
- auto-off RX/TX

Comandos rejeitados:

- `0x38` (NC on/off)
- `0x37` (NC Basic/Strong)

Motivo: a chave O/L/H é física. O status reflete a chave.

### 5.5 App Swift

- Menu bar app com `MenuBarExtra`.
- `LSUIElement=1` (sem Dock icon).
- Bundle ID `com.niko.djimic`.
- i18n `en` e `pt-BR`.
- Página principal com RX/TX, página “More Settings” com os grupos do app
  oficial, footer fixo e diagnóstico.
- Otimistic update nos controles e deduplicação de snapshots para reduzir
  re-renders.
- Snapshots de UI em light/dark/pt-BR gerados por teste.

## 6. Estrutura do repositório

```
Package.swift                 Swift Package
Sources/
  DJIMicProtocol/             protocolo puro (CRC, DUML, modelos, comandos)
  DJIMicTransport/            wrapper Swift do IOKit
  DJIMicSession/              sessão, fila, ACK, estado, reconexão
  DJIMicUI/                   SwiftUI, design system, i18n, AppModel
  DJIMicApp/                  @main, MenuBarExtra, composição
  DJIMicProbe/                CLI Swift de validação
  DJIMicUSB/                  shim C/IOKit
tests/
  test_protocol.py            testes Python originais (não remover)
  DJIMicProtocolTests/        testes Swift do protocolo
  DJIMicSessionTests/         testes com transporte falso
  DJIMicUITests/              i18n e snapshots
tools/poc/
  dji_protocol.py             implementação Python do DUML/parser
  dji_probe.py                CLI de laboratório
  README.md                   uso do POC
Packaging/                    Info.plist e InfoPlist.strings
Scripts/build-app.sh          gera Release/DJIMic.app
docs/                         esta documentação
```

## 7. Fluxo de dados e componentes

```
USBTransporting (IOKit)
        │ Data
        ▼
DUMLParser ──► ParsedFrame
        │
        ▼
MicSession ──► DeviceSnapshot
        │              │
        │              ▼
        │          AppModel (@MainActor)
        │              │
        │              ▼
        └──────────► SwiftUI views
        ▲
        │ MicSetting / MicCommand
        │
   AppModel.send
```

Componentes principais:

| Componente | Arquivo | Papel |
|---|---|---|
| `USBTransporting` | `Sources/DJIMicTransport/USBTransporting.swift` | contrato de bytes |
| `IOKitUSBTransport` | `Sources/DJIMicTransport/IOKitUSBTransport.swift` | wrapper do shim C |
| `DJIMicUSB` | `Sources/DJIMicUSB/DJIMicUSB.c` | IOKit, open/claim/read/write |
| `DUMLParser` | `Sources/DJIMicProtocol/DUML.swift` | framing, CRC, pushes |
| `MicSetting` | `Sources/DJIMicProtocol/Settings.swift` | comandos tipados |
| `MicSession` | `Sources/DJIMicSession/MicSession.swift` | ACK, fila, estado, reconexão |
| `AppModel` | `Sources/DJIMicUI/AppModel.swift` | estado da UI e intents |
| `MenuBarPanel` | `Sources/DJIMicUI/Views/MenuBarPanel.swift` | painel e navegação |
| `MoreSettingsContent` | `Sources/DJIMicUI/Views/MoreSettingsContent.swift` | grupos do app oficial |

Fluxo de escrita:

1. view chama `AppModel.send(.gain(6))`;
2. `AppModel` aplica otimistic update;
3. `MicSession` cria o `MicSetting`/`MicCommand`, atribui sequência e escreve;
4. RX responde ACK;
5. `MicSession` resolve a continuação ou lança `rejected`;
6. o próximo status reconcilia o estado real.

## 8. Decisões e porquês

| Decisão | Motivo |
|---|---|
| Python para POC | Iteração rápida, pyusb/libusb já disponível |
| Swift para app | Nativo, SwiftUI, sem runtime extra |
| IOKit via shim C | Evita dependência de libusb no app; controle de baixo nível |
| `USBInterfaceOpenSeize` | A interface 6 já está com `accessoryd` |
| Retry em `IOCreatePlugInInterfaceForService` | Pode retornar “out of resources” na primeira tentativa |
| NC read-only | Comandos rejeitados e chave física confirmada |
| Bateria em bars | Só existe gauge de 3 bits, não porcentagem |
| Sem third-party | Requisito explícito do projeto |
| POC Python preservado | Ferramenta de laboratório e referência |
| i18n desde o início | Evitar strings hardcoded e permitir pt-BR/en |
| Menu bar app | Acesso rápido durante uso do mic |

### Decisões de produto

| Decisão | Valor |
|---|---|
| Formato do app | menu bar (`MenuBarExtra`), sem Dock (`LSUIElement=1`) |
| Bundle ID | `com.niko.djimic` |
| Idiomas | `en` e `pt-BR`, com fallback em inglês |
| Diagnóstico | janela separada, com export JSONL |
| Bateria | barras/estado, sem porcentagem inventada |
| More Settings | página interna replicando Audio Settings, Buttons & LED, General |
| NC | somente leitura, com explicação da chave física |
| Clipping | controle único que afeta RX e TX |
| Distribuição | fora da App Store, assinatura ad-hoc por enquanto |
| Dependências | nenhuma de terceiros |

### Fases planejadas

1. Reconhecimento USB e definição do canal de controle.
2. POC Python com leitura/escrita e validação de ACK.
3. Matriz de comandos no hardware real.
4. App Swift com protocolo portado e testado.
5. UI SwiftUI, i18n, design e diagnóstico.
6. Empacotamento, QA visual e merge na main.

Todas as fases acima foram concluídas em algum nível; o que resta está no
backlog de [`feature-ideas.md`](feature-ideas.md).

## 9. Estado atual

- `main` contém o app e a documentação.
- O app compila, roda e assume a interface 6.
- O POC Python continua funcional, mas precisa que o app seja fechado.
- `swift test` passa.
- Build do `.app` por `./Scripts/build-app.sh`.
- O app tem diagnóstico com frames e exportação JSONL.
- A UI foi validada por snapshots em claro/escuro/pt-BR; falta validação
  manual de clique/foco na barra de menus.

## 10. Branches e commits

```text
main
└── eb1f0f7  Polish menu bar panel layout and interactions
    └── a08ac10  Add native macOS menu bar app with modular Swift stack
        └── 662f5cd  [BASE]
```

Branches existentes:

- `feat/swift-menu-bar-app` — app Swift inicial.
- `feat/professional-ui` — polish visual, já mergeado na main.

Novas branches devem sair de `main`, salvo pedido diferente.

Nada foi enviado para remote até o momento.

## 11. Ambiente usado

- macOS 27.0.1
- Xcode 27.1 / Swift 6.4
- Python 3.12 via `uv`
- `pyusb` 1.3.1
- libusb via Homebrew
- sem dependências Swift externas

## 12. Limitações e armadilhas

- **Exclusividade USB:** app aberto bloqueia o POC Python.
- **Interface 6 + accessoryd:** no macOS, usar `USBInterfaceOpenSeize`.
- **NC:** não tentar escrever; `0x37`/`0x38` retornam `0xff`.
- **Bateria:** gauge 1–7; não inventar porcentagem.
- **Frames `5b 04`:** keepalive/periódico observado, ainda não decodificado.
- **Auto-off TX:** bit `0x08` do slot +6 parece “timer ativo”; não totalmente
  esclarecido.
- **Dois TXs:** o parser suporta, mas só um TX foi testado.
- **Firmware/format/reboot:** não enviar sem pesquisa e confirmação.
- **Plug-free external speaker (`0x0023`):** reinicia o RX; deixar para o fim.
- **App não é sandboxed:** sandbox bloquearia o acesso USB; distribuição
  direta.

## 13. Como continuar

1. Leia `docs/README.md` e `docs/reverse-engineering-handbook.md`.
2. Feche o app antes de rodar o POC Python.
3. Para validar um comando novo:
   - teste no POC com `raw` ou `set`;
   - confirme ACK `0x00`;
   - confirme mudança no status;
   - confirme efeito físico;
   - adicione ao `MicSetting`/UI/testes;
   - atualize `feature-matrix.md`.
4. Para adicionar UI:
   - use `AppModel.send`;
   - mantenha o estado do dispositivo como fonte da verdade;
   - adicione strings em `en` e `pt-BR`;
   - rode snapshots light/dark/pt-BR.

## 14. Backlog

Ver [`feature-ideas.md`](feature-ideas.md). Prioridades imediatas:

- presets;
- perfil por app;
- notificações;
- launch at login;
- Find my TX;
- medidor profissional.

Pesquisa futura:

- mute;
- RSSI/link quality;
- bateria via BLE;
- internal recording;
- pairing;
- Protocol Lab.

## 15. O que não fazer

- Não importar código de terceiros.
- Não remover `tools/poc/` nem `tests/test_protocol.py`.
- Não assumir que NC é gravável.
- Não inventar porcentagem de bateria.
- Não enviar comandos destrutivos sem confirmação.
- Não rodar POC e app ao mesmo tempo.
