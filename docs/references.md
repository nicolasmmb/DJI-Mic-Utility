# Referências consultadas

Este projeto foi implementado de forma independente. Nenhum arquivo, trecho de
código, documentação ou binário dos projetos abaixo foi copiado, vendorizado,
adicionado como submódulo ou baixado para dentro do repositório.

| Fonte | O que foi usado como referência | Data |
|---|---|---|
| `ShadowBitBasher/DJI-Mic-Control` (GitHub, Unlicense) | Existência do canal bulk na interface 6 (`0x06`/`0x86`), formato geral do framing DUML e semântica do ACK. | 2026-10-21 |
| `usokawa/dji-mic-mo` (GitHub, BSD-2-Clause) | Lista de VID/PID suportados, IDs de alguns comandos e offsets de leitura do status. | 2026-10-21 |
| Issue `usokawa/dji-mic-mo#1` | Confirmação de que o Mic Mini 2 RX tem chave física de NC e de que `0x37`/`0x38` retornam `0xff`; semântica do byte de resultado do ACK. | 2026-10-21 |
| Observação direta do dispositivo | Descritores USB, identidade, firmware, offsets confirmados, ACK e efeitos dos comandos. | 2026-10-21 |

Os fatos foram reescritos em `protocol-notes.md` e reimplementados em
`tools/poc/dji_protocol.py`. Os testes e resultados estão em
`feature-matrix.md`.

Se no futuro for necessário reutilizar código de terceiros, ele deverá ser
incorporado ao projeto de forma explícita, com licença e aviso de copyright,
e a decisão deverá ser registrada aqui. A regra atual é: **nenhum código de
terceiros**.
