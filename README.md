# reverse-dji-mic

Engenharia reversa e controle do receptor USB-C do DJI Mic Mini 2
(`2ca3:4011`) no macOS.

O receptor é a ponte entre o host e o transmissor: o app fala com o RX por USB
bulk (interface 6) e o RX encaminha os comandos para o TX por 2,4 GHz. Não há
USB direto no transmissor.

## Estado atual

- Protocolo DUML v2 identificado e reimplementado do zero.
- Probe em Python validado no hardware real:
  - leitura de identidade, firmware, status, bateria e nível de áudio;
  - escrita de gain, monitoring gain, safety track, mono/stereo, low cut,
    LEDs, voice tone, clipping control e auto-off do TX/RX;
  - leitura de bateria/carregamento do TX;
  - ACK com resultado (`0x00` aceito, `0xff` rejeitado).
- NC neste kit é uma chave física O/L/H e não aceita comando de escrita.

Detalhes: [`docs/protocol-notes.md`](docs/protocol-notes.md),
[`docs/usb-descriptors.md`](docs/usb-descriptors.md) e
[`docs/feature-matrix.md`](docs/feature-matrix.md).

## Rodar o probe

```bash
uv sync
uv run python tools/poc/dji_probe.py scan
uv run python tools/poc/dji_probe.py status
uv run python tools/poc/dji_probe.py monitor --levels
```

O `status` devolve um snapshot em JSON com identidade, RX e TX. O `monitor`
mostra os pushes conforme chegam.

Ver [`tools/poc/README.md`](tools/poc/README.md).

## App Swift (menu bar)

O app nativo está em `Sources/` e é documentado em
[`docs/swift-app.md`](docs/swift-app.md). Build:

```bash
swift test
./Scripts/build-app.sh
open Release/DJIMic.app
```

O POC Python continua intacto em `tools/poc/`.

## Próximos passos

1. Esclarecer os frames periódicos `5b 04` e validar o bit de carregamento.
2. Portar o protocolo validado para um módulo Swift interno.
3. App SwiftUI nativo usando IOKit, sem dependências de terceiros.

## Regra do repositório

Nenhum código, arquivo ou binário de projetos de terceiros é importado ou
baixado para dentro do projeto. Referências são usadas apenas como informação
e estão listadas em [`docs/references.md`](docs/references.md).
