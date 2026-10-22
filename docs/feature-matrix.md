# Matriz de recursos — Mic Mini 2 RX (`2ca3:4011`, fw 02.03.17.00)

Testes feitos em 2026-10-21 com o probe deste repositório. Cada linha foi
verificada com ACK + mudança no push de status; quando aplicável, o efeito
físico também foi observado (LED).

| Recurso | Comando | Target | Valores testados | ACK | Status mudou | Situação |
|---|---|---|---|---|---|---|
| Gain do RX | `0x0039` | `0x0000` | `0`, `6` | `0x00` | sim (`payload[11]`) | validado |
| Monitoring gain | `0x0026` | `0x0000` | `0`, `-6` | `0x00` | sim (`payload[16]`) | validado |
| Safety track | `0x0021` | `0x0000` | on/off | `0x00` | sim (`payload[37]`) | validado |
| Mono/Stereo | `0x0008` | `0x0000` | mono, stereo | `0x00` | sim (`payload[10]`) | validado |
| Low cut | `0x0003` | `0xffff` | on/off | `0x00` | sim (slot TX) | validado |
| LEDs | `0x000a` | `0xffff` | on/off | `0x00` | sim (slot TX) | validado (broadcast) |
| Voice tone | `0x0029` | `0x0001` | regular, bright | `0x00` | sim (slot TX) | validado |
| Clipping control | `0x001e` | `0x0000` | off/on | `0x00` | sim, RX e TX | validado |
| Clipping control (alias) | `0x0024` | `0x0000` | off/on | `0x00` | mesmo efeito do `0x001e` | validado |
| Auto-off TX | `0x0010` | `0xffff` | off/on | `0x00` | sim (slot TX) | validado |
| Auto-off RX | `0x0010` | `0x0000` | off/on | `0x00` | sim (RX) | validado |
| Bateria TX | — | — | leitura | — | gauge `1` = full, `charging=false` | leitura validada |
| NC ligado | `0x0038` | `0xffff`, `0x0000`, `0x0001` | off | `0xff` | não | rejeitado |
| NC Basic/Strong | `0x0037` | `0xffff`, `0x0000` | basic | `0xff` | não | rejeitado |

## Observações específicas deste kit

- O receptor tem **chave física O/L/H** para Off/Basic/Strong. O app oficial
  mostra o estado da chave; o protocolo não permite alterá-lo.
- O estado do NC aparece primeiro no RX, em `payload[9]` (`0x20` = ligado,
  `0x08` = Strong); o slot do TX reflete o mesmo estado cerca de 0,2 s depois.
- O ACK traz um byte de resultado: `0x00` aceito, `0xff` rejeitado. Isso é
  essencial para não tratar comando rejeitado como sucesso.
- O RX se identifica como `DJI Mic Mini 2`, não como “DJI Mic Series”. O app
  oficial exibe “DJI Mic Series” junto com o sufixo de endereço (`eda630`).
- Clipping Control (`0x001e` e `0x0024`) altera **os dois** flags: RX em
  `payload[37]` bit `0x10` e TX no slot `+8` bit `0x04`.
- Auto-off do TX usa `0x0010` com target broadcast; o estado fica no slot `+6`
  bit `0x10`. O bit `0x08` do mesmo byte aparece como “timer ativo” depois de
  religar o auto-off e não foi totalmente esclarecido.
- Auto-off do RX usa `0x0010` com target `0x0000`; o estado fica em
  `payload[10]` bit `0x01`.
- A bateria do TX é um gauge de 3 bits no slot `+7` (bits 2–4): `1` = cheio,
  `7` = vazio, `6` = aviso de bateria baixa (observado `1`, sem carregar).
  O receptor USB não expõe bateria própria no status.
- Os ajustes alterados durante os testes foram revertidos. O estado atual do
  kit pode ter sido mudado no app oficial entre uma sessão e outra.

## Ainda não validado

- Mic LED com target por TX (`0x000a` + `0x0001`/`0x0002`), usado pelo
  Find my TX; só o broadcast `0xffff` foi validado
- Turn on with camera (`0x0020`)
- Plug-free external speaker (`0x0023`) — reinicia o RX, deixar para o fim
- Faixa completa do gauge de bateria do TX (só o valor `1` foi observado)
- Bit de carregamento do TX em estado “carregando”
- Interpretação dos frames periódicos `5b 04` (byte 8 = `0x00`)
