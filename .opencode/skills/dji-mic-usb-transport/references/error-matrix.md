# Matriz de erros USB

| Erro | Causa | Correção |
|---|---|---|
| `device not found` | RX ausente/desligado, cabo, app aberto | conferir USB; fechar app; replugar |
| `access denied` | interface 6 ocupada | fechar app/POC; replugar |
| `kIOReturnExclusiveAccess` | outro cliente com seize | fechar concorrente |
| `kIOReturnNoResources` no plugin | interface ainda iniciando | retry de 1 ms |
| timeout de leitura | sem dados no momento | continuar; não reconectar |
| timeout de escrita | dispositivo ocupado/travado | conferir; replugar |
| lê 1022 bytes | vários frames no buffer | parser por stream |
| ACK não chega | seq errada, comando inválido, timeout | conferir frame; repetir |
| reconexão em loop | abrir antes de estabilizar | esperar 1 s |
| áudio some | dispositivo de áudio trocado | conferir `SPAudioDataType` |
| app não vê RX | POC aberto | fechar POC |

## Comandos úteis

```bash
ioreg -p IOUSB -l -w0 | grep -i 'Wireless Mic'
ioreg -r -n 'IOUSBHostInterface@6' -l -w0 | grep -E 'UsbExclusiveOwner|IOUserClientCreator'
system_profiler SPUSBDataType | grep -A20 -i 'wireless mic'
system_profiler SPAudioDataType | grep -A8 -i 'wireless mic'
lsof -p <pid> | grep -i iousb
```

## Recuperação

1. fechar app/POC;
2. desconectar;
3. esperar 5 s;
4. reconectar;
5. `scan`;
6. `status`.
