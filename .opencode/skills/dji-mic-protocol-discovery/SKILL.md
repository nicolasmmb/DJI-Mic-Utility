---
name: DJI Mic Protocol Discovery
description: Use when a DJI Mic command, status byte, target, or setting is unknown; covers safe differential testing, USB capture, hypothesis tracking, evidence, and promotion of findings into validated commands.
---

# DJI Mic Protocol Discovery

Skill autocontida para investigar comandos e offsets desconhecidos sem
quebrar o dispositivo e sem tratar suposição como fato.

## Escopo

Use para:

- descobrir comando de mute, RSSI, BLE battery, pairing, internal recording;
- mapear bytes desconhecidos do status;
- confirmar alvo (RX/TX1/TX2/broadcast) de um comando;
- entender o efeito de um valor;
- capturar tráfego do app oficial.

Não use para:

- validar um comando já conhecido (use `dji-mic-hardware-validation`);
- montar um frame do zero (use `dji-mic-packet-craft`);
- resolver acesso USB (use `dji-mic-usb-transport`).

## Contexto mínimo

- RX `0x2ca3:0x4011`, interface 6, bulk `0x06`/`0x86`.
- Comandos de 22 bytes, DUML v2.
- ACK de 14 bytes; byte 11 = `0x00` aceito / `0xff` rejeitado.
- Status type `0x03`; identidade `0x01`; nível `0x05`.
- NC é read-only no Mic Mini 2.
- Bateria é gauge de 7 níveis.
- App e POC Python não coexistem na interface 6.

## Métodos de descoberta

### 1. Teste diferencial

O mais seguro e disponível.

1. Baseline de 5–10 s:

```bash
uv run python tools/poc/dji_probe.py monitor --levels --raw --jsonl captures/antes.jsonl
```

2. Altere **uma** coisa (botão físico, app oficial ou comando candidato).
3. Capture de novo.
4. Compare os bytes do status.
5. Confirme o efeito físico.
6. Reverta.

### 2. Captura do app oficial

Se o comando não estiver nas referências:

- captura USB com analisador de hardware;
- ou Linux com `usbmon` + Wireshark;
- ou análise estática do app móvel;
- ou engenharia reversa do binário do app.

O projeto ainda não fez captura com analisador de hardware. Qualquer captura
deve ser registrada com data, firmware e contexto.

### 3. Referências públicas

Use apenas como hipótese:

- ShadowBitBasher/DJI-Mic-Control
- usokawa/dji-mic-mo
- issue `usokawa/dji-mic-mo#1`

Nenhum código desses projetos deve ser copiado para o repositório.

## Como formar hipóteses

Para um comando candidato, varie:

- command id (`0x0000`–`0xFFFF`);
- target: `0x0000`, `0x0001`, `0x0002`, `0xFFFF`;
- valor: `0`, `1`, `2`, `0xFF`;
- payload length;
- posição de flags.

Não faça fuzzing cego em massa. Comece pelos IDs próximos de comandos
conhecidos e por valores pequenos.

## Sinais de evidência

Um comando só é considerado descoberto se houver:

1. ACK `0x00` consistente;
2. mudança de status reproduzível;
3. efeito físico/áudio reproduzível;
4. reversão possível;
5. documentação do target e valor.

ACK isolado não basta. Status isolado também não basta.

## Template de hipótese

```text
Hipótese:
Comando:
Target:
Valor:
Firmware:
Captura/arquivo:
ACK:
Status antes:
Status depois:
Efeito físico:
Repetições:
Conclusão:
```

## Segurança

Nunca enviar sem pesquisa e confirmação:

- firmware update;
- formatação;
- factory reset;
- reboot do RX;
- comandos de bootloader;
- sequências longas de fuzzing.

Cuidados:

- uma variável por vez;
- backup do estado;
- reverter sempre;
- fechar o app antes do POC;
- não deixar o TX em estado estranho;
- se o dispositivo parar de responder, remova e reconecte o USB.

## Promoção para comando validado

Quando a hipótese virar fato:

1. registre command/target/valor;
2. registre o offset de leitura;
3. adicione ao packet-craft/commands;
4. adicione ao POC;
5. adicione ao `MicSetting` Swift se for para o app;
6. adicione teste;
7. atualize a documentação;
8. valide novamente com `dji-mic-hardware-validation`.

## Áreas desconhecidas atuais

- mute do TX;
- RSSI/qualidade do link;
- bateria em % via BLE;
- internal recording / 32-bit float;
- pairing/linking;
- frames `5b 04`;
- byte `payload[35]` do status;
- bit `+6 0x08` do auto-off (timer?);
- suporte real a dois TXs.

## Referências internas

- `references/discovery-method.md`
- `references/safety.md`

## Referência externa opcional

Não necessária para executar:

- `docs/reverse-engineering-handbook.md`
- `docs/references.md`
