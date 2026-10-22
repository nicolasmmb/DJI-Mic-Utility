---
name: DJI Mic Hardware Validation
description: Use when testing or validating a DJI Mic command on real hardware, interpreting ACK 0x00/0xff, comparing status pushes, restoring settings, or recording results in the feature matrix.
---

# DJI Mic Hardware Validation

Skill autocontida para provar que um comando funciona no hardware real, com
segurança e reversibilidade. Não exige leitura de outros documentos.

## Escopo

Use para:

- validar comando novo ou alterado;
- confirmar ACK;
- comparar status antes/depois;
- verificar efeito físico (LED, áudio);
- testar reconexão;
- registrar resultado.

Não use para:

- montar o frame do zero (use `dji-mic-packet-craft`);
- descobrir comando desconhecido (use `dji-mic-protocol-discovery`);
- resolver erro de USB (use `dji-mic-usb-transport`).

## Contexto operacional

- RX: `0x2ca3:0x4011`, interface 6, endpoints `0x06`/`0x86`.
- Firmware observado: `02.03.17.00`.
- TX: `DJI Mic Mini 2`.
- NC é read-only (chave O/L/H).
- Bateria é gauge de 7 níveis.
- O app e o POC Python não podem abrir a interface 6 ao mesmo tempo.

## Pré-condições

1. Feche o app (`Sair`) se for usar o POC Python.
2. Conecte o RX diretamente no Mac.
3. Ligue o TX e confirme que está linkado.
4. Confirme o dispositivo:

```bash
ioreg -p IOUSB -l -w0 | grep -i 'Wireless Mic'
uv run python tools/poc/dji_probe.py scan
```

5. Capture o baseline:

```bash
uv run python tools/poc/dji_probe.py status --raw
uv run python tools/poc/dji_probe.py monitor --levels --raw --jsonl captures/baseline.jsonl
```

## Regra principal

**Uma variável por vez.**

Não envie dois comandos, não mude dois ajustes e não teste dois valores
seguidos sem confirmar o estado entre eles.

## Fluxo de validação

1. Registre o valor atual.
2. Envie o comando.
3. Exija ACK `0x00`.
4. Espere o próximo push de status.
5. Confirme o campo alterado.
6. Confirme o efeito físico.
7. Reverta para o valor original.
8. Confirme que voltou.
9. Registre o resultado.

Se o ACK for `0xff`, pare. O comando não é suportado ou o target/valor está
errado.

## Comandos

```bash
# leitura consolidada
uv run python tools/poc/dji_probe.py status --raw

# monitor contínuo
uv run python tools/poc/dji_probe.py monitor --levels --raw

# escrita
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

# pacote bruto
uv run python tools/poc/dji_probe.py raw '55 16 04 fc ...'
```

O `set` retorna código 3 quando o receptor rejeita.

## Tabela de leitura

| Ajuste | Leitura |
|---|---|
| Gain RX | status `payload[11]` |
| Monitoring RX | status `payload[16]` |
| Stereo | `payload[10]` bit 2 |
| Safety | `payload[37]` bit 6 |
| Clipping | `payload[37]` bit 4 e TX `+8` bit 2 |
| Low cut | TX `+9` bit 5 |
| Mic LED | TX `+6` bit 1 (invertido) |
| Voice tone | TX `+9` bits 6–7 |
| Auto-off TX | TX `+6` bit 4 |
| Auto-off RX | `payload[10]` bit 0 |
| Bateria | TX `+7` bits 2–4 |
| Carregando | TX `+7` bit 1 |
| NC | `payload[9]` bits 5–3 |

## ACK

- `0x00` = aceito
- `0xff` = rejeitado
- Sem ACK em ~2 s = timeout

Um ACK aceito não prova efeito físico; o status e o teste manual provam.

## Testes específicos

### Gain

1. Leia o gain atual.
2. Envie `0`, depois `6`, depois o valor original.
3. Confirme `payload[11]` a cada passo.
4. Ouça/observe se o nível muda.

### Monitoring gain

1. Teste `0` e `-6`.
2. Confirme `payload[16]`.
3. Restaure.

### Safety track

1. Ligue.
2. Confirme `payload[37]` bit 6.
3. Desligue e confirme.

### Stereo

1. Envie `stereo` (valor 2).
2. Confirme `payload[10]` bit 2.
3. Volte para mono.

### Voice tone

1. Teste regular/rich/bright no TX1.
2. Confirme TX `+9`.
3. Restaure o tom original.

### Clipping

1. Teste `0x1E` e `0x24`.
2. Confirme RX `payload[37]` bit 4 e TX `+8` bit 2.
3. Restaure.

### Mic LED

1. Desligue e confirme TX `+6` bit 1.
2. Confirme o LED físico apagado.
3. Ligue novamente.

### Auto-off

1. TX: broadcast `0x10`, confirme TX `+6` bit 4.
2. RX: target RX `0x10`, confirme `payload[10]` bit 0.
3. Restaure.

### Reconexão

1. Com o app aberto, desconecte e reconecte o RX.
2. Confirme estado “reconnecting” e retorno a “connected”.
3. Confirme que o parser não ficou com frame parcial.
4. Repita com o POC Python (fechando o app).

## O que não testar sem pesquisa

- `0x0023` plug-free external speaker (reinicia o RX)
- `0x0020` turn on with camera (não validado)
- firmware update
- formatação de gravação interna
- factory reset
- fuzzing de comandos em massa

## Template de resultado

```text
Data:
Dispositivo/firmware:
Comando:
Target:
Valor:
ACK:
Status antes:
Status depois:
Efeito físico:
Revertido?:
Observações:
```

## Critério de aceite

Um comando só está validado quando:

- ACK `0x00`;
- campo de status muda como esperado;
- efeito físico confirma;
- valor original é restaurado;
- resultado é registrado.

## Referências internas

- `references/validation-checklist.md`
- `references/command-matrix.md`
- `references/report-template.md`

## Referência externa opcional

Não necessária para executar:

- `docs/feature-matrix.md`
- `docs/PROJECT-CONTEXT.md`
