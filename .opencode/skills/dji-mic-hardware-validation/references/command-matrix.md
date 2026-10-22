# Matriz de comandos

| Ajuste | Cmd | Target | Testar | Confirmar |
|---|---|---|---|---|
| Gain | `0x0039` | RX | 0, 6, original | `payload[11]` |
| Monitoring | `0x0026` | RX | 0, -6, original | `payload[16]` |
| Safety | `0x0021` | RX | on/off | `payload[37]` bit 6 |
| Stereo | `0x0008` | RX | stereo, mono | `payload[10]` bit 2 |
| Low cut | `0x0003` | broadcast | off/on | TX `+9` bit 5 |
| Mic LED | `0x000A` | broadcast | off/on | TX `+6` bit 1 + LED |
| Voice tone | `0x0029` | TX1 | rich, bright, regular | TX `+9` bits 6–7 |
| Clipping | `0x001E` | RX | off/on | RX `[37]` bit 4 + TX `+8` bit 2 |
| Clipping alias | `0x0024` | RX | off/on | mesmo |
| Auto-off TX | `0x0010` | broadcast | off/on | TX `+6` bit 4 |
| Auto-off RX | `0x0010` | RX | off/on | `payload[10]` bit 0 |
| NC | `0x0038`/`0x0037` | — | não testar escrita | esperado `0xFF` |

## Valores

- gain: int8 (-12 a +12)
- monitoring: int8 (-12 a +12)
- stereo: 0/2
- mic LED: 0 on, 2 off
- voice tone: 0/1/2
- clipping: 0/1
- auto-off: 0/1
- safety: 0/1

## Sinais

- ACK aceito: `0x00`
- rejeitado: `0xFF`
- timeout: ~2 s sem ACK
- status: ~10 Hz
- nível: ~10 Hz

## Comandos que exigem cuidado

- `0x0023` plug-free external speaker: reinicia o RX.
- `0x0020` turn on with camera: não validado.
- firmware/format/factory reset: proibidos.
