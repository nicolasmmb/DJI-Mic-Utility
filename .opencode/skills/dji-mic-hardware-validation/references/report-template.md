# Template de relatório de validação

```text
# Validação — <ajuste>

Data:
macOS:
App/POC versão:
Dispositivo: DJI Mic Mini 2 RX
Firmware RX:
Firmware TX:
Serial/sufixo (se relevante):

## Baseline

Comando:
Target:
Valor:
Status antes:
Arquivo de captura:

## Execução

ACK:
Sequência:
Status depois:
Efeito físico:
Outros ajustes alterados?:

## Reversão

Comando:
ACK:
Status final:
Efeito físico final:

## Conclusão

[ ] validado
[ ] rejeitado
[ ] inconclusivo

Observações:
```

## Regras

- Não colar serial completo em issue pública.
- Anexar JSONL só se não contiver dados sensíveis.
- Registrar a data e o firmware.
- Se o resultado for rejeitado, registrar o valor do ACK.
- Se for inconclusivo, explicar o que faltou.
