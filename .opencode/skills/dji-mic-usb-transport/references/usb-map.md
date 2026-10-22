# Mapa USB

## Identidade

| Campo | Valor |
|---|---|
| Vendor | `DJI Technology Co., Ltd.` |
| Produto | `Wireless Mic Rx` |
| VID:PID | `0x2ca3:0x4011` |
| Serial USB | `XSP12345678B` (descritor) |

## Interfaces

| Nº | Classe | Uso |
|---|---|---|
| 0 | HID | botões; não é controle |
| 1 | áudio control | controle de áudio |
| 3 | áudio streaming | entrada isoc |
| 6 | vendor `0xff/0xf0` | controle/telemetria |

## Interface 6

- Bulk OUT `0x06`
- Bulk IN `0x86`
- 64 bytes por pacote
- `SupportsIAP = Yes`
- aberta por `accessoryd` no macOS

## Abrir

macOS:
- IOKit legacy: `USBInterfaceOpenSeize`
- IOUSBHost: `IOUSBHostInterface`
- pyusb/libusb: claim interface

## Ler

- buffer 1024
- pode conter múltiplos frames
- timeout não é erro fatal
- parser por stream

## Escrever

- 22 bytes por comando
- timeout 0.5–1 s
- validar ACK

## Exclusividade

O primeiro cliente que abre com seize ganha. O segundo falha.

- app aberto → POC falha
- POC aberto → app falha

## Áudio

A entrada USB de 2 canais continua disponível mesmo com a interface 6
controlada.
