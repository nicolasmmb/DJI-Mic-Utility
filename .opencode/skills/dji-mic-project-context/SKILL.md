---
name: DJI Mic Project Context
description: Use when starting, resuming, or handing off work on the reverse-dji-mic project; provides the device, protocol, app, repository, constraints, branch rules, and specialist-skill routing needed to work without reading external docs.
---

# DJI Mic Project Context

Esta skill é autocontida. Tudo o que você precisa para começar está aqui.
Os links no final são apenas leitura opcional.

## Objetivo do projeto

Criar um app macOS de barra de menus para controlar o receptor USB-C de um kit
DJI Mic Mini 2 sem depender do app oficial de celular, com uma implementação
própria do protocolo USB.

## Hardware observado

| Item | Valor |
|---|---|
| Receptor | `Wireless Mic Rx` |
| VID:PID | `0x2ca3:0x4011` |
| Interface de controle | 6, vendor-specific (`0xff/0xf0`) |
| Endpoints | bulk OUT `0x06`, bulk IN `0x86` |
| Produto no protocolo | `DJI Mic Mini 2` |
| Firmware observado | `02.03.17.00` |
| Interface HID | 0 (botões); não é o canal de configuração |
| Áudio | entrada USB de 2 canais, 48 kHz |

O RX tem uma chave física **O/L/H** para Off/Basic/Strong de redução de ruído.
O protocolo **não escreve** esse estado neste kit.

## Topologia

```
macOS / app
   │ USB bulk, interface 6
   ▼
RX (ponte)
   │ 2,4 GHz
   ▼
TX1 / TX2
```

Não existe USB direto no transmissor. O RX encaminha comandos e devolve o
estado do TX nos pushes de status.

## Estado atual

- Protocolo DUML v2 identificado e reimplementado internamente.
- POC Python funcional em `tools/poc/`.
- App SwiftUI nativo funcional em `Sources/`, com menu bar, i18n e
  diagnóstico.
- `main` contém o app, os docs e o POC.
- Comandos validados: gain, monitoring gain, safety track, mono/stereo, low
  cut, mic LED, voice tone, clipping, auto-off RX/TX.
- NC é read-only.
- Bateria do TX é um gauge de 7 níveis (`1` cheio … `7` vazio).
- O app ocupa a interface 6 com exclusividade enquanto está aberto.

## Regras não negociáveis

1. Nenhum código, binário ou arquivo de terceiros entra no repositório.
2. O POC Python em `tools/poc/` e `tests/test_protocol.py` não podem ser
   removidos.
3. Não enviar firmware update, formatação, factory reset ou reboot sem
   pesquisa e confirmação.
4. Toda escrita USB precisa validar ACK `0x00`; `0xff` é rejeição.
5. Não inventar porcentagem de bateria; só existe gauge.
6. Não tentar escrever NC no Mic Mini 2.
7. Novas strings de UI precisam existir em `en` e `pt-BR`.
8. Novas views precisam funcionar em light/dark e com Reduce Motion.
9. O app e o POC Python não podem abrir a interface 6 ao mesmo tempo.

## Mapa do repositório

```text
Package.swift
Sources/
  DJIMicProtocol/   CRC, DUML, parser, modelos, MicSetting
  DJIMicTransport/  USBTransporting + wrapper IOKit
  DJIMicSession/    MicSession, ACK, estado, reconexão
  DJIMicUI/         SwiftUI, design system, i18n, AppModel
  DJIMicApp/        @main, MenuBarExtra, composição
  DJIMicProbe/      CLI Swift de validação
  DJIMicUSB/        shim C/IOKit
tools/poc/          POC Python
tests/              testes Python e Swift
docs/               documentação canônica
Scripts/build-app.sh
Packaging/
```

## Comandos rápidos

```bash
# app (fechar antes de usar o POC Python)
swift test
swift run djimic-swift-probe
./Scripts/build-app.sh
open Release/DJIMic.app

# POC Python
uv sync
uv run python tools/poc/dji_probe.py scan
uv run python tools/poc/dji_probe.py status --raw
uv run python tools/poc/dji_probe.py monitor --levels --raw
```

## Qual skill carregar depois

| Necessidade | Skill |
|---|---|
| Montar/decodificar frames, CRC, offsets | `dji-mic-packet-craft` |
| Testar/validar comando no hardware | `dji-mic-hardware-validation` |
| Descobrir comando/offset desconhecido | `dji-mic-protocol-discovery` |
| Problema de USB, claim, IOKit, pyusb | `dji-mic-usb-transport` |
| Alterar AppModel, views, i18n, build | `dji-mic-swift-app` |

## Branches e commits

```text
main
└── eb1f0f7  Polish menu bar panel layout and interactions
    └── a08ac10  Add native macOS menu bar app with modular Swift stack
        └── 662f5cd  [BASE]
```

Branches históricas: `feat/swift-menu-bar-app`, `feat/professional-ui`.
Novas branches devem sair de `main`.

## Ambiente

- macOS 27
- Xcode 27.1 / Swift 6.4
- Python 3.12 via `uv`
- pyusb 1.3.1
- libusb via Homebrew
- sem dependências Swift externas

## Limitações conhecidas

- NC read-only.
- Bateria só em gauge.
- Frames `5b 04` ainda não decodificados.
- Apenas um TX testado; parser suporta dois.
- Mute, RSSI, BLE battery, internal recording e pairing não descobertos.
- `0x23` reinicia o RX; não testar sem necessidade.
- `0x20` ainda não validado.

## Referência opcional

Somente para explicação histórica mais longa; **não é necessária** para
executar:

- `docs/PROJECT-CONTEXT.md`
- `docs/reverse-engineering-handbook.md`
- `docs/feature-ideas.md`
