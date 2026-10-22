# Comandos validados

| Ajuste | Cmd | Target | Valor | Leitura |
|---|---|---|---|---|
| Gain RX | `0x0039` | `0x0000` | int8 | status `payload[11]` |
| Monitoring gain | `0x0026` | `0x0000` | int8 | status `payload[16]` |
| Safety track | `0x0021` | `0x0000` | 0/1 | status `payload[37]` bit 6 |
| Mono/Stereo | `0x0008` | `0x0000` | 0 mono / 2 stereo | status `payload[10]` bit 2 |
| Low cut | `0x0003` | `0xFFFF` | 0/1 | TX slot `+9` bit 5 |
| Mic LED | `0x000A` | `0xFFFF` | 0 on / 2 off | TX slot `+6` bit 1 |
| Voice tone | `0x0029` | `0x0001`/`0x0002` | 0/1/2 | TX slot `+9` bits 6–7 |
| Clipping | `0x001E` | `0x0000` | 0/1 | RX `payload[37]` bit 4 + TX `+8` bit 2 |
| Clipping alias | `0x0024` | `0x0000` | 0/1 | mesmo efeito |
| Auto-off TX | `0x0010` | `0xFFFF` | 0/1 | TX slot `+6` bit 4 |
| Auto-off RX | `0x0010` | `0x0000` | 0/1 | status `payload[10]` bit 0 |
| NC on/off | `0x0038` | qualquer | — | **rejeitado `0xFF`** |
| NC Basic/Strong | `0x0037` | qualquer | — | **rejeitado `0xFF`** |

## Observações

- `0x1E` e `0x24` são aliases no firmware `02.03.17.00`.
- Voice tone é por unidade; os outros ajustes de TX são broadcast.
- Mic LED é invertido.
- Stereo usa `2`, não `1`.
- Gain negativo:
  - `-6` → `0xFA`
  - `-12` → `0xF4`
- NC é chave física O/L/H.
- Bateria do TX:
  - bits 2–4 de `+7`
  - 1 cheio, 6 baixa, 7 vazio
  - bit 1 = carregando
- `+6 0x08` aparece após religar auto-off; provável timer ativo.
- `payload[35]` do RX ainda desconhecido.

## Exemplos

Gain 0:

```
55 16 04 fc 02 5a a3 29 40 5b 01 02 00 00 00 00 39 00 01 00 7a 7a
```

Gain 6:

```
55 16 04 fc 02 5a 34 12 40 5b 01 02 00 00 00 00 39 00 01 06 ...
```

NC off rejeitado:

```
55 16 04 fc 02 5a 57 e5 40 5b 01 02 ff ff 00 00 38 00 01 00 02 c1
```
