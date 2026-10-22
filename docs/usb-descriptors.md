# Descritores USB observados

Levantamento feito nesta máquina com o receptor conectado, usando o próprio
probe do projeto (`uv run python tools/poc/dji_probe.py scan`).

## Identificação

| Campo | Valor |
|---|---|
| Fabricante | `DJI Technology Co., Ltd.` |
| Produto | `Wireless Mic Rx` |
| VID:PID | `0x2ca3:0x4011` |
| Serial reportado | `XSP12345678B` |
| Velocidade | USB 2.0 (12 Mbps) |

O serial acima é o que o dispositivo expõe no descritor USB. O serial real do
receptor vem no push de identidade do protocolo (ver `protocol-notes.md`).

## Interfaces

| Interface | Classe | Subclasse | Protocolo | Endpoints | Uso |
|---|---|---|---|---|---|
| 0 | `0x03` HID | `0x00` | `0x00` | `0x82` IN, `0x03` OUT | Botões / consumer control. Não é o canal de configuração. |
| 1 | `0x01` áudio | `0x01` | `0x00` | — | Controle de áudio USB. |
| 3 | `0x01` áudio | `0x02` | `0x00` | `0x81` IN (isoc, 288) | Streaming de áudio de entrada. |
| 6 | `0xff` vendor | `0xf0` | `0x00` | `0x86` IN, `0x06` OUT (bulk, 64) | **Canal de configuração e telemetria.** |

A interface 6 aparece no `ioreg` com `SupportsIAP = Yes` e é aberta pelo
`accessoryd` no macOS. O probe consegue reivindicá-la para uso em modo
usuário; não foi necessário desabilitar o `accessoryd`.

## Consequências para o app

- O canal de controle é **bulk**, não HID.
- O app não precisa de DriverKit nem de kext.
- A entrada de áudio continua sendo tratada pelo driver USB Audio do sistema;
  o app só controla configurações.
- Um app fora da App Store, sem sandbox, consegue abrir a interface com
  `IOKit`/`libusb`. Se optarmos por sandbox, será necessário entitlement de
  acesso USB.
