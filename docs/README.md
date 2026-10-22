# Documentação do projeto

Este diretório é a memória técnica do projeto. Se você é um novo chat/agente,
leia nesta ordem antes de alterar qualquer coisa:

1. [`PROJECT-CONTEXT.md`](PROJECT-CONTEXT.md) — objetivo, decisões, histórico,
   estado atual, branches e como continuar.
2. [`reverse-engineering-handbook.md`](reverse-engineering-handbook.md) — como
   o protocolo foi descoberto, como montar/enviar mensagens, como depurar e
   como validar comandos novos.
3. [`protocol-notes.md`](protocol-notes.md) — formato canônico dos frames,
   offsets de status/identidade/nível e comandos validados.
4. [`feature-matrix.md`](feature-matrix.md) — o que foi testado no hardware e
   qual foi o resultado.
5. [`usb-descriptors.md`](usb-descriptors.md) — descritores USB observados.
6. [`references.md`](references.md) — repositórios e fontes consultadas; nada
   de código de terceiros foi incorporado.
7. [`swift-app.md`](swift-app.md) — arquitetura e build do app macOS.
8. [`feature-plan.md`](feature-plan.md) — plano consolidado: viabilidade,
   implementação, dados e aprendizado de máquina, validações e roteiro.
9. [`feature-ideas.md`](feature-ideas.md) — backlog original (histórico).

## Resumo em uma frase

App macOS de barra de menus que controla o receptor DJI Mic Mini 2
(`2ca3:4011`) por USB bulk (interface 6), usando um protocolo DUML v2
reimplementado internamente em Python (POC) e Swift (app), sem código de
terceiros.

## Estado atual

- Protocolo e comandos principais validados no hardware.
- POC Python funcional em `tools/poc/`.
- App SwiftUI modular funcionando, com menu bar, i18n, diagnóstico e
  snapshots visuais.
- `main` contém o app e a documentação.
- Noise Reduction é **somente leitura** no Mic Mini 2 (chave física O/L/H).
- Bateria do TX é um gauge de 7 níveis; não há porcentagem no protocolo USB.
- O app ocupa a interface 6 com exclusividade enquanto está aberto.

## Regras do projeto

- Nenhum código, binário ou arquivo de repositórios de terceiros entra no
  projeto.
- Referências externas servem só como informação; a implementação é nossa.
- O POC Python deve continuar existindo e funcionando.
- Não enviar comandos de firmware, formatação ou reboot sem pesquisa e
  confirmação.
- Toda escrita deve validar ACK `0x00`; `0xff` significa rejeição.
- Novas strings precisam existir em `en` e `pt-BR`.
- Novas views devem funcionar em light/dark e com Reduce Motion.

## Comandos rápidos

```bash
# Python POC (fechar o app antes)
uv sync
uv run python tools/poc/dji_probe.py scan
uv run python tools/poc/dji_probe.py status --raw
uv run python tools/poc/dji_probe.py monitor --levels --raw

# Swift
swift test
swift run djimic-swift-probe
./Scripts/build-app.sh
open Release/DJIMic.app
```

## Skills do OpenCode

As skills ficam em `.opencode/skills/` e são autocontidas. Cada uma carrega o
contexto necessário dentro do próprio diretório; `docs/` é só leitura
opcional.

| Skill | Uso |
|---|---|
| `dji-mic-project-context` | contexto inicial e roteamento |
| `dji-mic-packet-craft` | montar/decodificar frames |
| `dji-mic-hardware-validation` | testar/validar no hardware |
| `dji-mic-protocol-discovery` | descobrir comandos/offsets |
| `dji-mic-usb-transport` | USB/IOKit/pyusb |
| `dji-mic-swift-app` | app SwiftUI |

Novos chats devem carregar `dji-mic-project-context` primeiro e depois a skill
especialista da tarefa. Se a sessão atual não listar as skills, abra uma nova
sessão.

## Prompt sugerido para um novo chat

```text
Leia docs/README.md, docs/PROJECT-CONTEXT.md,
docs/reverse-engineering-handbook.md, docs/protocol-notes.md,
docs/feature-matrix.md e docs/references.md antes de agir.
O POC Python em tools/poc não pode ser removido.
Não importe código de terceiros para o repositório.
```
