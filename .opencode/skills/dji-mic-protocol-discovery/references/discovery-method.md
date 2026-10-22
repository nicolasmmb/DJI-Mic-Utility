# Método de descoberta

## 1. Definir a pergunta

Exemplo:

> Qual comando mute o TX1?

Não comece com “vou fuzzar tudo”. Defina:

- funcionalidade;
- alvo provável;
- estado observável;
- como reverter.

## 2. Baseline

```bash
uv run python tools/poc/dji_probe.py monitor --levels --raw --jsonl captures/antes.jsonl
```

Capture 5–10 s. Salve o estado consolidado:

```bash
uv run python tools/poc/dji_probe.py status --raw
```

## 3. Alterar uma coisa

Opções:

- botão físico do TX;
- app oficial no celular;
- comando candidato no POC.

## 4. Capturar depois

```bash
uv run python tools/poc/dji_probe.py monitor --levels --raw --jsonl captures/depois.jsonl
```

## 5. Comparar

Procure:

- ACK novo;
- byte de status alterado;
- identidade/level alterado;
- frame novo;
- timing.

## 6. Repetir

Mínimo: 2–3 repetições. Uma mudança isolada pode ser ruído.

## 7. Reverter

Confirme que voltou ao baseline.

## 8. Promover

Se houver evidência:

- command id;
- target;
- valor;
- offset de leitura;
- efeito físico;
- taxa de sucesso.

## Captura USB

### Linux

`usbmon` + Wireshark:

```bash
sudo modprobe usbmon
# abrir interface usbmon no Wireshark
```

### Hardware

Analisador USB 2.0 entre o host e o RX.

### App oficial

Capturar o tráfego do app oficial e comparar com o que já sabemos. A interface
6 tem suporte a iAP; o app iOS pode usar iAP2, mas o DUML bruto continua
funcionando no macOS.

## Evitar

- fuzzing de command IDs em massa;
- valores altos sem entender;
- comandos de bootloader;
- targets errados com valores destrutivos;
- loops de escrita sem ACK.
