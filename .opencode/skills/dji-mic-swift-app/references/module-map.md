# Mapa dos módulos

```
DJIMicApp
  └── DJIMicUI
        ├── DJIMicProtocol
        └── DJIMicSession
              ├── DJIMicProtocol
              └── DJIMicTransport
                    └── DJIMicUSB (C/IOKit)
```

## Responsabilidades

| Módulo | Pode | Não pode |
|---|---|---|
| `DJIMicProtocol` | CRC, frames, modelos, `MicSetting` | IOKit, SwiftUI |
| `DJIMicTransport` | bytes, USB | DUML |
| `DJIMicSession` | ACK, estado, reconexão | SwiftUI |
| `DJIMicUI` | views, AppModel, i18n | IOKit |
| `DJIMicApp` | composição, MenuBarExtra | protocolo |

## Arquivos-chave

| Arquivo | Papel |
|---|---|
| `Sources/DJIMicProtocol/DUML.swift` | parser |
| `Sources/DJIMicProtocol/Settings.swift` | `MicSetting` |
| `Sources/DJIMicTransport/IOKitUSBTransport.swift` | wrapper |
| `Sources/DJIMicUSB/DJIMicUSB.c` | IOKit |
| `Sources/DJIMicSession/MicSession.swift` | sessão |
| `Sources/DJIMicUI/AppModel.swift` | estado da UI |
| `Sources/DJIMicUI/Views/MenuBarPanel.swift` | painel |
| `Sources/DJIMicUI/Views/MoreSettingsContent.swift` | More Settings |
| `Scripts/build-app.sh` | bundle |

## Fluxo de escrita

```
View
 → AppModel.send
 → MicSession.send
 → MicSetting.command.encoded
 → transport.write
 → ACK
 → status
 → DeviceSnapshot
 → AppModel
 → View
```

## Deduplicação

`MicSession` ignora snapshots iguais (exceto `updatedAt`) para evitar
re-renders. O `AppModel` aplica otimistic update antes do ACK.
