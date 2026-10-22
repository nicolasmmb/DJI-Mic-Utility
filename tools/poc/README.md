# Probe POC — DJI Wireless Mic RX

CLI de laboratório para validar o protocolo do receptor `2ca3:4011` no macOS.
Usa `pyusb`/`libusb` apenas como ferramenta de POC; o app final não depende
deste diretório.

## Ambiente

O projeto usa `uv`:

```bash
uv sync
uv run python tools/poc/dji_probe.py scan
```

`libusb` é fornecido pelo Homebrew (`brew install libusb`) e o `pyusb` é
declarado em `pyproject.toml`.

## Comandos

```bash
# Descritores USB e interfaces
uv run python tools/poc/dji_probe.py scan

# Telemetria (identidade, status e nível)
uv run python tools/poc/dji_probe.py monitor
uv run python tools/poc/dji_probe.py monitor --levels
uv run python tools/poc/dji_probe.py monitor --raw --jsonl captures/run.jsonl

# Snapshot consolidado em JSON
uv run python tools/poc/dji_probe.py status
uv run python tools/poc/dji_probe.py status --raw

# Escrita
uv run python tools/poc/dji_probe.py set gain 6
uv run python tools/poc/dji_probe.py set monitoring-gain -6
uv run python tools/poc/dji_probe.py set safety-track on
uv run python tools/poc/dji_probe.py set stereo stereo
uv run python tools/poc/dji_probe.py set low-cut off
uv run python tools/poc/dji_probe.py set mic-led off
uv run python tools/poc/dji_probe.py set voice-tone bright --tx 1
uv run python tools/poc/dji_probe.py set clipping-control on
uv run python tools/poc/dji_probe.py set auto-off-tx off
uv run python tools/poc/dji_probe.py set auto-off off
uv run python tools/poc/dji_probe.py set mute on --tx 1
uv run python tools/poc/dji_probe.py set rec on --tx 1
uv run python tools/poc/dji_probe.py set vibration on
uv run python tools/poc/dji_probe.py set float32 on
uv run python tools/poc/dji_probe.py set rec-stop-lock on
uv run python tools/poc/dji_probe.py set startup-auto-recording on

# Sem enviar
uv run python tools/poc/dji_probe.py set gain 6 --dry-run

# Pacote arbitrário
uv run python tools/poc/dji_probe.py raw '55 16 04 fc ...'
```

O `set` imprime o pacote, espera o ACK e retorna código 3 se o receptor
responder `0xff` (comando rejeitado).

## Cuidados

- Comece sempre por `monitor` e faça backup do estado atual.
- Um ajuste por vez; confirme ACK e mudança no status.
- **Não** use este probe para atualização de firmware.
- `plug-free external speaker` (`0x0023`) reinicia o receptor; deixe para o
  fim, se for testar.
- No Mic Mini 2 o NC é uma chave física O/L/H; `noise-cancel` e
  `noise-cancel-mode` são rejeitados de propósito pelo firmware. O estado é
  lido do status.

## Estado validado

Ver `docs/feature-matrix.md`. Resumo: gain, monitoring gain, safety track,
mono/stereo, low cut, LEDs, voice tone, clipping control, auto-off do TX/RX e
leitura de bateria do TX funcionam; NC é somente leitura neste kit (chave
física O/L/H).

No DJI Mic 2 também foram validados `mute` (`0x0009`, por TX), `rec`
(`0x0002`, por TX), `vibration` (`0x0004`), `float32` (`0x000C`),
`rec-stop-lock` (`0x000B`) e `startup-auto-recording` (`0x002E`). O `status`
expõe `muted`, `recording`, `float32_recording`, `vibration`, `rec_stop_lock`,
`startup_auto_recording`, `recording_time_total` e
`recording_time_remaining`. Detalhes em `docs/dji-mic-2-discovery-report.md`.


A bateria do TX aparece no `status` como `battery_gauge` (1 = cheio,
7 = vazio), `battery_full`, `battery_low` e `charging`. O receptor USB não tem
bateria própria.
