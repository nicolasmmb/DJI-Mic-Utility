# Referências consultadas

Este projeto foi implementado de forma independente. Nenhum arquivo, trecho de
código, documentação, binário ou submódulo dos projetos abaixo foi copiado,
vendorizado ou adicionado ao repositório.

As fontes foram usadas para **fatos do protocolo e da API do sistema**, e os
fatos foram reescritos e reimplementados internamente.

## Projetos de referência

### ShadowBitBasher/DJI-Mic-Control

- Repositório: https://github.com/ShadowBitBasher/DJI-Mic-Control
- Documento: https://github.com/ShadowBitBasher/DJI-Mic-Control/blob/main/PROTOCOL.md
- Licença: Unlicense
- O que usamos como referência:
  - mesmo VID/PID `0x2ca3:0x4011`;
  - canal bulk na interface 6 (`0x06`/`0x86`);
  - framing DUML, CRC-8/CRC-16 e semântica do ACK;
  - conceito de snapshots de status/identidade/nível;
  - comandos de áudio e settings.
- O que **não** usamos:
  - código Rust, GUI Tauri, testes, assets ou documentação copiada;
  - o projeto não é dependência nem submódulo.

### usokawa/dji-mic-mo

- Repositório: https://github.com/usokawa/dji-mic-mo
- Web app: https://usokawa.github.io/dji-mic-mo/dji-mic-mo.html
- Licença: BSD-2-Clause
- O que usamos como referência:
  - lista de VID/PID suportados (`0x4011`, `0x4015`, `0x4115`);
  - interface/endpoints para `0x4011`;
  - IDs de comandos como gain, monitoring gain, voice tone, clipping;
  - offsets de leitura do status e identidade;
  - comportamento de NC no Mic Mini 2.
- O que **não** usamos:
  - JavaScript, HTML, Python CLI ou udev rules do projeto;
  - nenhum arquivo foi baixado para dentro do repositório.

### usokawa/dji-mic-mo#1

- Issue: https://github.com/usokawa/dji-mic-mo/issues/1
- Título: *Mic Mini 2 receiver (2ca3:4011) test results on macOS*
- O que usamos como referência:
  - confirmação de que o Mic Mini 2 RX tem chave física O/L/H;
  - `0x37`/`0x38` retornam `0xff` em broadcast, TX1 e RX;
  - byte de resultado do ACK (`0x00` aceito, `0xff` rejeitado);
  - clipping `0x1e`/`0x24` no firmware `02.03.17.00`;
  - voice tone e low cut funcionando no firmware `02.03.17.00`.

## APIs do sistema

### IOKit / IOUSBHost

- Headers locais do SDK macOS:
  - `IOUSBHost.framework/Headers/IOUSBHostObject.h`
  - `IOUSBHost.framework/Headers/IOUSBHostInterface.h`
  - `IOUSBHost.framework/Headers/IOUSBHostPipe.h`
  - `IOKit.framework/Headers/usb/IOUSBLib.h`
- O que usamos:
  - `IOUSBHostInterface`/`IOUSBHostDevice` e matching por VID/PID/interface;
  - `USBInterfaceOpenSeize` para assumir a interface 6 ocupada pelo
    `accessoryd`;
  - `IOCreatePlugInInterfaceForService` com `kIOCFPlugInInterfaceID`;
  - `GetNumEndpoints`/`GetPipeProperties` para achar os pipes bulk;
  - `ReadPipeTO`/`WritePipeTO` para bulk com timeout.
- O shim C do projeto implementa isso internamente em
  `Sources/DJIMicUSB/DJIMicUSB.c`.

### libusb (Darwin)

- Código de referência: https://github.com/libusb/libusb/blob/master/libusb/os/darwin_usb.c
- Commit sobre retry: https://github.com/libusb/libusb/commit/0b381a81bed9051bfac7a4f5a16358182c7e7f9a
- O que usamos como referência:
  - `IOCreatePlugInInterfaceForService` pode retornar “out of resources” na
    primeira tentativa e precisa de retry;
  - uso de `kIOCFPlugInInterfaceID` na criação do plugin;
  - ordem de open/claim/Release;
  - comportamento de `USBInterfaceOpenSeize`.
- Não usamos libusb como dependência do app; o POC Python usa pyusb/libusb
  apenas como ferramenta de laboratório.

## Observação direta do dispositivo

Levantamentos feitos nesta máquina:

- descritores USB (`ioreg`, `system_profiler`);
- identidade e firmware no protocolo;
- status e nível a ~10 Hz;
- ACK `0x00`/`0xff`;
- efeitos físicos de LED, NC, clipping, auto-off, voice tone;
- áudio USB de 2 canais;
- interface 6 com `accessoryd`;
- app Swift e POC Python não podem abrir a interface ao mesmo tempo.

## Regra para o futuro

Se for necessário reutilizar código de terceiros:

1. a decisão deve ser explícita;
2. a licença e o copyright devem ser preservados;
3. o código deve ser incorporado de forma rastreável;
4. o motivo deve ser registrado neste arquivo.

A regra atual continua: **nenhum código de terceiros**.
