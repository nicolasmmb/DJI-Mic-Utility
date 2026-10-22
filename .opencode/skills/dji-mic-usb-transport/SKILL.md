---
name: DJI Mic USB Transport
description: Use when diagnosing or implementing USB access for the DJI Mic RX: interface 6, bulk endpoints 0x06/0x86, IOKit, pyusb/libusb, accessoryd ownership, exclusive access, reconnection, or USB errors.
---

# DJI Mic USB Transport

Skill autocontida para levar bytes entre o Mac e a interface de controle do
receptor, sem depender de documentação externa.

## Escopo

Use para:

- encontrar o dispositivo;
- abrir/claim da interface 6;
- ler `0x86` e escrever `0x06`;
- entender `accessoryd`/exclusividade;
- resolver “device not found”, “access denied”, timeout;
- implementar reconexão;
- diferenciar POC Python e app Swift.

Não use para:

- montar comandos (use `dji-mic-packet-craft`);
- validar um ajuste (use `dji-mic-hardware-validation`);
- descobrir comandos (use `dji-mic-protocol-discovery`).

## Identidade e topologia

| Item | Valor |
|---|---|
| VID:PID | `0x2ca3:0x4011` |
| Produto | `Wireless Mic Rx` |
| Interface de controle | 6 (`0xff/0xf0`) |
| Bulk OUT | `0x06` |
| Bulk IN | `0x86` |
| Interface HID | 0 (não usar) |
| Áudio | interface 3, entrada USB de 2 canais |

```
host → interface 6 endpoint 0x06 → RX → 2,4 GHz → TX
host ← interface 6 endpoint 0x86 ← RX
```

## Regra de ouro

A interface 6 é **exclusiva**. Se o app estiver aberto, o POC Python não
consegue abrir. Se o POC estiver aberto, o app não consegue.

Verifique:

```bash
ioreg -r -n 'IOUSBHostInterface@6' -l -w0 | grep -E 'UsbExclusiveOwner|IOUserClientCreator'
```

## macOS: accessoryd

No macOS, a interface 6 aparece com `SupportsIAP = Yes` e é aberta pelo
`accessoryd`. Para assumi-la:

- IOKit: `USBInterfaceOpenSeize`
- pyusb/libusb: `claim_interface` com o backend Darwin
- app: shim C em `Sources/DJIMicUSB/DJIMicUSB.c`

`USBInterfaceOpenSeize` pode retornar erro se outro cliente se recusar a
fechar. Nesse caso, feche o app/POC concorrente e reconecte o cabo.

## Abrir no Python

O POC já faz o fluxo completo:

```bash
uv run python tools/poc/dji_probe.py scan
uv run python tools/poc/dji_probe.py status --raw
```

Fluxo mínimo:

```python
import usb.core, usb.util

dev = usb.core.find(idVendor=0x2CA3, idProduct=0x4011)
if dev is None:
    raise SystemExit("device not found")

dev.set_configuration()
usb.util.claim_interface(dev, 6)

# write: dev.write(0x06, packet, timeout=1000)
# read:  dev.read(0x86, 1024, timeout=1000)
```

Em macOS, `detach_kernel_driver` não existe; o claim/seize é feito pelo
libusb. Não use `set_configuration` se o dispositivo já estiver configurado
sem tratar o erro.

## Abrir no Swift/IOKit

Fluxo do app:

1. `IOServiceGetMatchingServices` em `IOUSBHostInterface`.
2. Filtrar `idVendor`, `idProduct`, `bInterfaceNumber == 6`.
3. `IOCreatePlugInInterfaceForService` com `kIOCFPlugInInterfaceID`.
4. `USBInterfaceOpenSeize`.
5. `GetNumEndpoints` + `GetPipeProperties` para achar `0x06`/`0x86`.
6. `WritePipeTO`/`ReadPipeTO`.

Detalhe importante: `IOCreatePlugInInterfaceForService` pode retornar
“out of resources” na primeira tentativa. O shim tenta novamente algumas
vezes.

## Ler e escrever

- Leitura pode retornar múltiplos frames em um único buffer (ex.: 1022 bytes).
- O parser deve varrer o stream por `0x55`.
- Timeout de leitura é normal; não é desconexão.
- Escrita de comando tem 22 bytes; leitura usa buffer de 1024.
- Após erro de leitura, feche, limpe o parser, reconecte.
- O áudio USB continua funcionando com o controle aberto.

## Reconexão

Sequência correta:

1. detectar erro de leitura/escrita;
2. `close`;
3. marcar estado `reconnecting`;
4. limpar parser parcial;
5. tentar reabrir a cada ~1 s;
6. ao abrir, publicar `connected`;
7. aguardar identidade/status.

Não reutilize um parser com frame parcial de uma sessão anterior.

## Matriz de erros

| Sintoma | Causa provável | Correção |
|---|---|---|
| `device not found` | cabo, RX desligado ou app aberto | conferir USB; fechar app |
| `access denied` / exclusive | outro cliente na interface 6 | fechar app/POC; replugar |
| timeout constante | endpoint errado ou dispositivo ocupado | conferir `0x86`; fechar concorrente |
| lê 1022 bytes | buffer contém vários frames | parser por stream |
| áudio some | dispositivo de áudio mudou | conferir `system_profiler SPAudioDataType` |
| reconecta em loop | abrir antes do dispositivo estabilizar | atraso de 1 s e retry |
| ACK não chega | comando inválido/ocupado | conferir seq e timeout |

## Debug

```bash
system_profiler SPUSBDataType | grep -A20 -i 'wireless mic'
ioreg -p IOUSB -l -w0 | grep -i 'Wireless Mic'
ioreg -r -n 'IOUSBHostInterface@6' -l -w0 | grep -E 'UsbExclusiveOwner|IOUserClientCreator'
system_profiler SPAudioDataType | grep -A8 -i 'wireless mic'
lsof -p <pid> | grep -i iousb
```

## POC vs app

- POC: Python + pyusb/libusb.
- App: Swift + IOKit via shim C, sem libusb.
- Ambos usam a mesma interface e endpoints.
- Nunca rodar os dois ao mesmo tempo.

## Referências internas

- `references/usb-map.md`
- `references/error-matrix.md`

## Referência externa opcional

Não necessária para executar:

- `docs/usb-descriptors.md`
- `docs/reverse-engineering-handbook.md`
