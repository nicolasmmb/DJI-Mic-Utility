---
name: DJI Mic Swift App
description: Use when changing the macOS SwiftUI app for DJI Mic: MicSession, AppModel, views, design system, i18n, diagnostics, tests, packaging, or adding a setting end-to-end.
---

# DJI Mic Swift App

Skill autocontida para evoluir o app macOS sem quebrar as camadas, o
protocolo ou a experiência de uso.

## Escopo

Use para:

- adicionar/alterar UI;
- adicionar um setting de ponta a ponta;
- mexer em `MicSession`, `AppModel`, views, i18n;
- rodar testes e build;
- empacotar o `.app`.

Não use para:

- inventar comando novo (use `dji-mic-protocol-discovery`);
- validar no hardware (use `dji-mic-hardware-validation`);
- montar frame do zero (use `dji-mic-packet-craft`).

## Contexto do produto

- App de barra de menus, sem Dock (`LSUIElement=1`).
- Bundle ID `com.niko.djimic`.
- Painel 380 × 540 pt.
- i18n `en` e `pt-BR`.
- Sem dependências de terceiros.
- RX `0x2ca3:0x4011`, interface 6.
- NC read-only; bateria em gauge.

## Módulos e regras

```
DJIMicProtocol   DUML, CRC, modelos, MicSetting
DJIMicTransport  USBTransporting + IOKit
DJIMicSession    MicSession, ACK, estado, reconexão
DJIMicUI         AppModel, SwiftUI, design system, i18n
DJIMicApp        @main, MenuBarExtra, composição
DJIMicUSB        shim C/IOKit
```

Regras:

- `DJIMicProtocol` não importa IOKit nem SwiftUI.
- `DJIMicTransport` não conhece DUML.
- `DJIMicSession` depende de `USBTransporting`/`MicClient`.
- `DJIMicUI` não acessa USB.
- `DJIMicApp` só compõe.
- O POC Python não é dependência do app.

## Fluxo de dados

```
USB bytes
  → DUMLParser → ParsedFrame
  → MicSession → DeviceSnapshot
  → AppModel (@MainActor)
  → SwiftUI views

View → AppModel.send(.gain(6))
  → MicSession.send
  → MicCommand + sequência
  → USB 0x06
  → ACK/status
```

## APIs principais

```swift
// comando tipado
try await session.send(.gain(6))
try await session.send(.voiceTone(.bright, unit: 1))
try await session.send(.clippingControl(true))

// estado
session.snapshots   // AsyncStream<DeviceSnapshot>
session.events      // AsyncStream<SessionEvent>

// UI
model.send(.lowCut(false))
```

`MicSession` já:

- abre a interface;
- lê continuamente;
- resolve ACK por sequência;
- reconecta;
- deduplica snapshots;
- expõe diagnóstico.

## Adicionar um setting

1. Validar comando no hardware.
2. Adicionar caso em `MicSetting` (`Sources/DJIMicProtocol/Settings.swift`).
3. Adicionar leitura em `DUML.swift` se necessário.
4. Adicionar comando ao POC (`tools/poc/dji_probe.py`).
5. Adicionar teste em `tests/DJIMicProtocolTests/`.
6. Adicionar binding/controle na view.
7. Adicionar strings em `en` e `pt-BR`.
8. Atualizar `feature-matrix`/docs.
9. Rodar testes e validar no hardware.

Exemplo de caso:

```swift
case safetyTrack(let enabled):
    return MicCommand(
        target: .receiver,
        command: 0x0021,
        value: enabled ? 1 : 0
    )
```

## UI

Estado atual:

- Header: modelo, firmware, status, bateria.
- Receiver: NC read-only, gain, monitoring, mono/stereo, safety.
- Transmitter: voice tone, nível, bateria.
- Link **More** no header do TX.
- More Settings replica:
  - Audio Settings: Low Cut, Clipping
  - Buttons & LED Indicators: Mic LED
  - General: Auto Off
- Footer fixo: Diagnostics, Quit.

Convenções:

- Cards arredondados, spacing 4/8/12/16/20.
- `Toggle` para booleanos.
- `Picker` segmentado para 3–5 opções.
- `Slider` para monitoring gain.
- `LabeledContent`/`SettingRow` para labels.
- SF Symbols e cores semânticas.
- `monospacedDigit` para dB/bateria.
- Otimistic update no `AppModel.send`.
- Não animar layout a cada status.
- Reduce Motion desliga transições e animações.
- VoiceOver labels/values nos controles.

## i18n

- `Sources/DJIMicUI/Resources/en.lproj/Localizable.strings`
- `Sources/DJIMicUI/Resources/pt-BR.lproj/Localizable.strings`
- Toda chave precisa existir nos dois.
- Não hardcodar texto de UI.
- Logs técnicos podem ficar em inglês.
- Teste de paridade em `tests/DJIMicUITests/LocalizationTests.swift`.

## Testes

```bash
swift test
swift test --filter rendersHostingViewSnapshot
swift test --filter rendersPortuguesePanel
swift test --filter rendersDarkPanel
```

Cobertura atual:

- protocolo (CRC, frame, status, identidade, nível, ACK);
- sessão com transporte falso (aceite/rejeição);
- i18n (paridade de chaves);
- snapshots light/dark/pt-BR.

## Build e distribuição

```bash
./Scripts/build-app.sh
open Release/DJIMic.app
```

O script:

1. compila em release;
2. cria `Release/DJIMic.app`;
3. copia o binário e o `Info.plist`;
4. copia o resource bundle de i18n;
5. assina ad-hoc.

## Armadilhas

- Não colocar lógica de protocolo na view.
- Não acessar IOKit direto na UI.
- Não ignorar ACK `0xff`.
- Não atualizar a UI só no próximo status sem feedback; use otimistic update.
- Não publicar snapshots idênticos; o `MicSession` deduplica.
- Não esquecer `pt-BR`.
- Não quebrar light/dark.
- Não rodar o app e o POC Python juntos.
- Não commitar `Release/` nem `.build/`.

## Referências internas

- `references/module-map.md`
- `references/ui-conventions.md`
- `references/settings.md`

## Referência externa opcional

Não necessária para executar:

- `docs/swift-app.md`
- `docs/feature-ideas.md`
