# Playbook de ganhos — DJI Mic Control

Documento orientado a valor. Cada ideia responde a cinco perguntas: **por que
gera ganho**, **como funciona**, **como implementar**, **como usar** e **como
medir o ganho**. No final há um plano step-by-step (passo a passo) com 100
passos numerados.

Complementa [`feature-plan.md`](feature-plan.md), que descreve viabilidade e
arquitetura. Aqui o foco é retorno.

Convenção: toda sigla aparece expandida em parênteses. O glossário está em
[`feature-plan.md`](feature-plan.md), seção 14.

---

## 1. O que conta como ganho

“Ganho” neste documento não é número de funcionalidades. É uma melhoria
mensurável em uma destas cinco dimensões:

| Tipo de ganho | Pergunta que responde | Exemplo |
|---|---|---|
| Tempo | Quanto tempo o usuário economiza? | Preset aplicado em 1 clique em vez de 8 ajustes |
| Confiabilidade | Quantos erros ou takes perdidos são evitados? | Alerta de bateria antes de o transmissor morrer |
| Qualidade de áudio | O resultado soa melhor? | Sound check (verificação de som) e medidor de clipping (corte) |
| Confiança | O usuário acredita no que vê? | Estado do dispositivo como fonte da verdade e logs sem serial |
| Alcance | O produto entra em mais fluxos? | CLI (interface de linha de comando), URL scheme (esquema de URL) e atalhos |

Toda ideia abaixo tem um indicador associado. Sem indicador, não é ganho; é
opinião.

### 1.1 Linha de base (baseline)

Antes de implementar, medir o estado atual em uma sessão real:

- Tempo para deixar o kit pronto (abrir o painel, ajustar tudo).
- Número de ajustes manuais por sessão.
- Takes perdidos por bateria, clipping (corte) ou queda de link (enlace).
- Tempo para encontrar o transmissor quando some.
- Número de comandos rejeitados sem explicação.

Sem essa linha de base, não há como provar ganho depois.

---

## 2. Ranking de ideias por retorno

| # | Ideia | Ganho principal | Indicador | Esforço | Risco |
|---|---|---|---|---|---|
| 1 | Presets (predefinições) | Tempo e consistência | Tempo até pronto | 3 dias | Baixo |
| 2 | Perfil automático por aplicativo | Zero cliques | Ajustes manuais por sessão | 2 dias | Baixo |
| 3 | Bateria com tempo restante | Evita take perdido | Takes perdidos por bateria | 2 dias | Médio |
| 4 | Alerta de link degradado | Evita falha silenciosa | Quedas por hora | 2 dias | Médio |
| 5 | Find my TX (encontrar transmissor) | Tempo | Tempo para encontrar | 1 dia | Baixo |
| 6 | Sound check (verificação de som) | Qualidade | Takes com clipping | 4 dias | Médio |
| 7 | Medidor com alerta de clipping (corte) | Qualidade | Takes com clipping | 3 dias | Baixo |
| 8 | Backup e restauração | Tempo e portabilidade | Tempo para configurar outra máquina | 1,5 dia | Baixo |
| 9 | Protocol Lab (laboratório de protocolo) | Destrava mute (silenciamento) e RSSI (indicador de intensidade do sinal recebido) | Comandos descobertos | 4 dias | Médio |
| 10 | CLI (interface de linha de comando), URL scheme (esquema de URL) e atalhos | Alcance | Automações funcionando | 2 dias | Baixo |
| 11 | Launch at login (iniciar ao fazer login) | Disponibilidade | Sessões com app já aberto | 0,5 dia | Baixo |
| 12 | Menu bar compacto (barra de menus) | Informação sem abrir painel | Cliques para ver estado | 1 dia | Baixo |
| 13 | Notificações de estado | Confiabilidade | Eventos percebidos a tempo | 1,5 dia | Baixo |
| 14 | Notarização e assinatura | Confiança e distribuição | Instalações sem bloqueio | 1 dia | Baixo |
| 15 | CI (integração contínua) e testes | Qualidade percebida | Regressões por release | 0,5 dia | Baixo |

As ideias 11 a 15 são ganhos indiretos: não são o motivo da compra, mas
aumentam retenção e reduzem suporte.

---

## 3. Ideias detalhadas

### 3.1 Presets (predefinições)

**Por que gera ganho.** Configurar o kit para uma entrevista leva de 30 a 60
segundos e envolve 6 a 8 ajustes. Um preset reduz isso a um clique e elimina
esquecimentos (por exemplo, sair com safety track desligado). Também cria
consistência entre sessões: o som de hoje é igual ao de ontem.

**Como funciona.** Um perfil é um conjunto nomeado de ajustes. Aplicar um
perfil significa enviar comandos em sequência, aguardar o ACK (confirmação) de
cada um e só considerar sucesso se todos forem aceitos.

**Como implementar.**

- `MicProfile`, `ReceiverProfile` e `TransmitterProfile` como DTOs (objetos de
  transferência de dados) `Codable`.
- `ProfileStore` em `Sources/DJIMicStore`, gravando em
  `~/Library/Application Support/com.niko.djimic/profiles.json`.
- `AppModel.apply(_ profile:) async -> ApplyReport`, com progresso,
  cancelamento e aborto no primeiro `0xff` (rejeição).
- Estado `isApplyingProfile` que desabilita os controles durante a aplicação.
- Presets iniciais: Interview (entrevista), Outdoor (externo), Podcast,
  Music (música) e Streaming (transmissão).
- “Save current as preset” (salvar configuração atual como preset).
- Importar e exportar JSON (JavaScript Object Notation).

**Como usar.**

1. Abrir o painel.
2. Clicar no seletor de preset no header.
3. Escolher “Interview”.
4. Ver a barra de progresso e o resultado: “7 aplicados, 0 rejeitados”.
5. Se algo falhar, o app mostra exatamente qual ajuste e por quê.

**Como medir.** Cronometrar “tempo até pronto” antes e depois, em cinco
sessões. Meta: redução de 70%. Contar ajustes manuais por sessão. Meta: cair
de 8 para 0–1.

**Limite.** `lowCut` (corte de graves), `micLED` (LED (diodo emissor de luz) do microfone) e
`autoOffTX` (desligamento automático do transmissor) são broadcast (difusão):
valem para todos os transmissores. Só `voiceTone` (tom de voz) é por unidade.
Um preset não consegue deixar TX1 (transmissor 1) e TX2 (transmissor 2)
diferentes nesses campos.

### 3.2 Perfil automático por aplicativo

**Por que gera ganho.** Elimina o clique. Ao entrar no Zoom, o kit já está em
modo entrevista; ao abrir o OBS (Open Broadcaster Software), já está em modo
transmissão. O ganho é tempo e redução de erro em transições rápidas.

**Como funciona.** O macOS avisa quando um aplicativo passa a ser o primeiro
plano. O app consulta um mapa `bundleIdentifier` (identificador de pacote) →
preset e aplica depois de um debounce (atraso de estabilização) de 300–500
milissegundos.

**Como implementar.**

- Observar `NSWorkspace.didActivateApplicationNotification` (notificação de
  ativação de aplicativo).
- Ignorar o próprio bundle `com.niko.djimic`; abrir o painel também gera
  ativação.
- Verificar se o painel está aberto via `onAppear`/`onDisappear` do
  `MenuBarPanel` (painel da barra de menus) e não aplicar nesse caso.
- Debounce com `Task` cancelável.
- Mapa persistido em `UserDefaults` (preferências do usuário).
- Automação desligada por padrão, com opt-in explícito.
- Registrar no diagnóstico “perfil Interview aplicado porque Zoom ativou”.

**Como usar.**

1. Abrir Preferências → Automação.
2. Ligar “Automation” (automação).
3. Arrastar ou escolher um aplicativo e associar a um preset.
4. Voltar ao trabalho. Ao trocar de aplicativo, o perfil é aplicado.

**Como medir.** Contar quantas vezes o usuário ajustou algo manualmente após a
troca de aplicativo. Meta: menos de uma correção por sessão.

**Limite.** Não aplicar durante uma chamada em andamento se o preset mudar
áudio de forma perceptível. Preferir presets que não alterem o gain (ganho) em
excesso.

### 3.3 Bateria com tempo restante

**Por que gera ganho.** O medo real não é “bateria em 40%”, é “o transmissor
vai morrer no meio da entrevista”. Uma estimativa de tempo restante com
incerteza evita take perdido e permite trocar o transmissor na pausa.

**Como funciona.** O protocolo expõe um gauge (escala) de 7 níveis. O app
registra quando o gauge muda e estima a taxa de descarga para o estado atual:
NC (cancelamento de ruído), low cut (corte de graves) e gravação. Com isso
projeta o tempo até o nível vazio.

**Como implementar.**

- `BatteryHistory` em `DJIMicStore`, com amostras de gauge e timestamp (marca
  temporal).
- Estimador de taxa por estado: regressão simples ou tabela calibrada.
- Exibir “~40 min” com sufixo de confiança (“estimativa”).
- Notificação em gauge 6 e em gauge 7.
- Nunca exibir porcentagem.

**Como usar.**

1. O header mostra o ícone de bateria e, ao passar o mouse, “~40 min restantes
   (estimativa)”.
2. Ao chegar em gauge 6, o app notifica “TX1 (transmissor 1) com bateria
   baixa, ~15 min”.
3. O usuário troca ou recarrega na pausa.

**Como medir.** Contar takes perdidos por bateria por mês. Meta: zero. Comparar
a estimativa com o tempo real até o gauge 7 em cinco ciclos; erro aceitável de
20%.

**Limite.** Sem histórico, a primeira estimativa é grosseira. O gauge tem 7
níveis; a incerteza é real e deve aparecer na UI (interface do usuário).

### 3.4 Alerta de link (enlace) degradado

**Por que gera ganho.** Quedas de link aparecem como falha silenciosa: o áudio
some e o usuário só percebe depois. Um alerta antecipado permite aproximar o
transmissor ou trocar de posição antes de perder a fala.

**Como funciona.** O app mede latência de ACK (confirmação), jitter (variação
de tempo entre frames (quadros)), lacunas de sequência e perda. EWMA (média
móvel ponderada exponencialmente) suaviza; CUSUM (soma cumulativa) detecta
mudança; um HMM (modelo oculto de Markov) de 3 estados dá “bom, degradado,
perdido” com confiança.

**Como implementar.**

- `LinkMonitor` em `DJIMicStore`.
- Métricas por janela de 5 segundos.
- CUSUM (soma cumulativa) com linha de base calibrada em sessão estável.
- Estado exibido como badge (indicador) no header, não como número de RSSI
  (indicador de intensidade do sinal recebido).
- Notificação apenas na transição para degradado, com rate limit (limite de
  frequência).

**Como usar.**

1. O header mostra um ícone de link (enlace) verde, amarelo ou vermelho.
2. Ao ficar amarelo, uma notificação sugere “aproxime o transmissor”.
3. O diagnóstico registra o evento com horário e métricas.

**Como medir.** Quedas por hora antes e depois. Meta: reduzir em 50% as quedas
percebidas como falha. Contar falsos positivos; meta: menos de um por sessão.

**Limite.** Sem RSSI (indicador de intensidade do sinal recebido) real, é um
indicador derivado. Não prometer distância em metros.

### 3.5 Find my TX (encontrar transmissor)

**Por que gera ganho.** O transmissor é pequeno e some na mesa ou no estojo. O
ganho é o tempo de procura: de minutos para segundos.

**Como funciona.** O comando `0x000A` controla o LED (diodo emissor de luz).
Alternar ligado e desligado 3–4 vezes torna o transmissor visível.

**Como implementar.**

- Validar no hardware se o comando aceita target (alvo) por unidade
  (`0x0001`/`0x0002`).
- `MicSetting.led(unit:on:)` ou um comando dedicado.
- Alternar com espera pelo status, não com tempo fixo.
- `defer` (execução garantida na saída) para restaurar o estado anterior.
- Restaurar também ao desconectar.
- Confirmação se o transmissor estiver em uso.

**Como usar.**

1. Abrir o painel e clicar em “Find” (encontrar) ao lado do transmissor.
2. O LED (diodo emissor de luz) pisca três vezes em ~2 segundos.
3. O estado anterior é restaurado automaticamente.

**Como medir.** Tempo cronometrado para encontrar o transmissor. Meta: menos de
30 segundos. Contar casos em que o LED (diodo emissor de luz) ficou desligado por falha; meta: zero.

**Limite.** Se o comando por unidade não for aceito, o recurso pisca os dois
transmissores ao mesmo tempo.

### 3.6 Sound check (verificação de som)

**Por que gera ganho.** Evita gravar uma entrevista inteira com nível baixo ou
distorcido. Substitui “teste 1, 2, 3” sem referência por uma sugestão
objetiva.

**Como funciona.** O app captura 10 segundos do áudio do receptor, separa fala
de silêncio, mede pico, RMS (valor eficaz), LUFS (unidades de sonoridade
relativas à escala completa) e piso de ruído, e sugere gain (ganho), low cut
(corte de graves) e distância do microfone.

**Como implementar.**

- `DJIMicAudio` com AUHAL (Audio Unit Hardware Abstraction Layer) e seleção
  explícita do dispositivo.
- VAD (detecção de atividade de voz) por energia, ZCR (taxa de cruzamento por
  zero) e planicidade espectral.
- Piso de ruído por *minimum statistics* (estatísticas de mínimo).
- Regra de sugestão: alvo de −18 dBFS (decibéis relativos à escala máxima)
  RMS (valor eficaz) e pico abaixo de −6 dBFS (decibéis relativos à escala
  máxima).
- Botão “Apply suggestion” (aplicar sugestão); nunca automático.

**Como usar.**

1. Clicar em “Sound check”.
2. Falar normalmente por 10 segundos, na distância de uso.
3. Ver o relatório: “fala em −24 dBFS (decibéis relativos à escala máxima),
   ruído em −60, sugira gain (ganho) +6 e low cut (corte de graves) ligado”.
4. Aplicar ou descartar.

**Como medir.** Takes com clipping (corte) ou nível baixo por sessão. Meta:
zero take inutilizável por nível. Taxa de aceitação da sugestão; meta: acima de
60%.

**Limite.** A sugestão é heurística. Não mede o ambiente como um medidor de SPL
(nível de pressão sonora).

### 3.7 Medidor com alerta de clipping (corte)

**Por que gera ganho.** Clipping (corte) é irreversível. Ver o pico em tempo
real e receber um alerta evita perder a melhor take.

**Como funciona.** O medidor calcula dBFS (decibéis relativos à escala máxima),
peak hold (retenção de pico), RMS (valor eficaz) e contagem de amostras no
máximo. Um contador acumulado por take mostra se houve corte.

**Como implementar.**

- Buffer circular de 30 segundos no módulo de áudio.
- Contagem de clipping (corte) por amostra em ±1,0.
- Histórico de 30 segundos desenhado com `Canvas` (tela de desenho).
- Alerta visual e notificação ao primeiro clipping (corte).
- Taxa de atualização de 15–30 Hz (hertz).

**Como usar.**

1. O medidor aparece no painel principal.
2. O ponto vermelho acende no primeiro clipping (corte) e permanece até o
   usuário limpar.
3. O contador mostra “2 clips nesta sessão”.

**Como medir.** Takes com clipping (corte) por sessão. Meta: zero sem aviso.

**Limite.** O USB (Universal Serial Bus) pode entregar um sinal já limitado
pelo receptor; o medidor vê a saída digital.

### 3.8 Backup e restauração

**Por que gera ganho.** Trocar de máquina, reinstalar ou compartilhar um setup
com a equipe deixa de ser retrabalho. Também é seguro contra experimentos:
salvar antes de testar.

**Como funciona.** Exportar todos os ajustes em JSON (JavaScript Object
Notation) com versão de esquema e restaurar com validação e relatório.

**Como implementar.**

- Reutilizar `MicProfile` com `schema` (versão do esquema).
- Validação de faixas antes de aplicar.
- Bloco `broadcast` (difusão) separado do bloco por transmissor.
- Relatório de aplicados, rejeitados e ignorados.
- Exportação sem serial.

**Como usar.**

1. Preferências → Backup → Exportar.
2. Salvar o arquivo.
3. Em outra máquina, Importar e confirmar.
4. Ler o relatório e corrigir o que foi rejeitado.

**Como medir.** Tempo para configurar uma máquina nova. Meta: menos de 2
minutos.

**Limite.** Ajustes broadcast (difusão) não preservam diferenças entre
transmissores.

### 3.9 Protocol Lab (laboratório de protocolo)

**Por que gera ganho.** É um ganho meta: acelera a descoberta de mute
(silenciamento), RSSI (indicador de intensidade do sinal recebido), pairing
(pareamento) e gravação interna. Sem ele, cada descoberta exige um script
novo.

**Como funciona.** O app mostra os frames (quadros) recebidos de forma
decodificada, permite filtrar, comparar capturas e enviar comandos crus com
proteção.

**Como implementar.**

- `MicSession.sendRaw(_ command: MicCommand)`.
- `FrameInspector` (inspetor de quadros) e buffer de ~5.000 frames (quadros).
- Filtros por tipo, ID (identificador) e target (alvo); busca.
- Envio cru com “Developer mode” (modo desenvolvedor), confirmação digitada e
  denylist (lista de bloqueio): `0x20`, `0x23`, reset (reinício), formatação e
  firmware.
- Export JSONL (JSON Lines, linhas no formato JSON (JavaScript Object
  Notation)) com redação de serial.
- Comparação de capturas por byte.

**Como usar.**

1. Ativar o modo desenvolvedor.
2. Abrir Diagnóstico → Protocol Lab.
3. Filtrar por `status` e observar os bytes.
4. Caminhar com o transmissor e comparar as capturas.
5. Enviar um comando candidato, ver o ACK (confirmação) e reverter.

**Como medir.** Número de comandos descobertos e validados por mês. Meta: um
por mês no início.

**Limite.** Não substitui captura do aplicativo oficial para descobrir mute
(silenciamento) e pairing (pareamento).

### 3.10 CLI (interface de linha de comando), URL scheme (esquema de URL) e atalhos

**Por que gera ganho.** Coloca o kit dentro de fluxos existentes: OBS (Open
Broadcaster Software), Stream Deck, Shortcuts (Atalhos) e scripts. Cada
automação economiza cliques por sessão.

**Como funciona.** Uma URL como `djimic://preset/interview` ou um comando
`djimic preset interview` aplica o preset. Se o app estiver aberto, o comando é
roteado para a sessão existente; se não, o CLI (interface de linha de comando)
abre e fecha a conexão.

**Como implementar.**

- `CFBundleURLTypes` (tipos de URL do pacote) e handler (tratador) no
  `AppDelegate`.
- Target (alvo) executável `djimic` em `Sources/DJIMicCLI`.
- Saída `--json` (JavaScript Object Notation) e códigos de saída estáveis.
- Detecção de app aberto para evitar duas sessões USB (Universal Serial Bus).
- Atalhos locais com `keyboardShortcut` (atalho de teclado) e globais com
  Carbon `RegisterEventHotKey` (registro de tecla de atalho).

**Como usar.**

1. No Stream Deck, criar um botão que abre
   `djimic://preset/streaming`.
2. No terminal, rodar `djimic status --json`.
3. No Shortcuts (Atalhos), chamar a ação “Apply Mic Profile”
   (aplicar perfil do microfone).

**Como medir.** Número de automações ativas por usuário e cliques economizados
por sessão.

**Limite.** A interface 6 é exclusiva; nunca abrir duas conexões.

---

## 4. Ganhos indiretos que aumentam retenção

### 4.1 Launch at login (iniciar ao fazer login)

O app está sempre disponível quando o usuário pluga o receptor. Ganho: uma
etapa a menos no início de cada sessão. Implementação com `SMAppService`
(serviço de gerenciamento de aplicativos), dependente de assinatura estável.

### 4.2 Menu bar compacto (barra de menus)

Mostrar bateria baixa, clipping (corte) e conexão sem abrir o painel. Ganho:
uma consulta de dois segundos em vez de abrir e fechar a janela.

### 4.3 Notificações de estado

Bateria baixa, desconexão, clipping (corte) e mudança de NC (cancelamento de
ruído) pela chave física. Ganho: o usuário descobre o problema na hora, não
depois.

### 4.4 Notarização e assinatura

Sem isso, o usuário enfrenta Gatekeeper (porteiro do macOS) e perde confiança.
Ganho: instalação sem atrito e possibilidade de início automático.

### 4.5 CI (integração contínua) e testes

Cada release sai com menos regressão. Ganho: confiança e menos suporte.

### 4.6 Redação de serial no diagnóstico

Hoje o export de frames (quadros) crus inclui o serial. Corrigir é requisito de
privacidade e aumenta a confiança de quem compartilha logs (registros).

---

## 5. Se “ganho” significar receita

Se o objetivo for monetização, os itens acima se organizam em três camadas:

| Camada | O que entrega | Papel |
|---|---|---|
| Grátis | Controle básico, presets, medidor simples, find my TX (encontrar transmissor) | Aquisição e confiança |
| Pro | Automação por aplicativo, sound check (verificação de som), gravação com safety track (faixa de segurança), backup e restauração, CLI (interface de linha de comando) | Receita recorrente |
| Equipe | Perfis compartilhados, backup em lote, diagnóstico exportável | Receita por assento |

Pré-requisitos comerciais: notarização, assinatura estável, atualização
automática e uma política clara de privacidade (nada de áudio na nuvem).

Não implementar cobrança antes de P4 (notarização) e P6 (integração contínua),
porque a experiência de instalação quebrada destrói a conversão.

---

## 6. Plano step-by-step (passo a passo) com 100 passos

Cada passo tem um critério de conclusão. A ordem respeita dependências: nada de
áudio antes da base, nada de App Intents antes do projeto Xcode.

### Fase 0 — Fundação (passos 1–15)

**1.** Criar a branch `feat/gain-playbook` a partir de `main`. Pronto quando:
`git status` limpo.
**2.** Criar `PreferencesStore` com `UserDefaults` (preferências do usuário) e
prefixo `com.niko.djimic.`. Pronto quando: teste de leitura e escrita passa.
**3.** Criar `MicProfile`, `ReceiverProfile` e `TransmitterProfile` `Codable`.
Pronto quando: round-trip de JSON (JavaScript Object Notation) preserva todos
os campos.
**4.** Criar `ProfileStore` em `Sources/DJIMicStore`. Pronto quando: grava e lê
`profiles.json` em Application Support.
**5.** Adicionar `DJIMicStore` ao `Package.swift` e aos testes. Pronto quando:
`swift test` compila.
**6.** Criar `AppServices` como dono único de `MicSession`, `ProfileStore`,
`PreferencesStore` e serviços. Pronto quando: o app sobe com uma única sessão.
**7.** Migrar a criação do `AppModel` para `AppServices`. Pronto quando: painel
e diagnóstico continuam funcionando.
**8.** Adicionar `AppDelegate` via `NSApplicationDelegateAdaptor`. Pronto
quando: o app inicia e encerra sem warnings.
**9.** Criar `TelemetryRecorder` escrevendo JSONL (JSON Lines, linhas no formato
JSON). Pronto quando: uma sessão de 1 minuto gera arquivo válido.
**10.** Implementar redação de serial. Pronto quando: teste confirma que o
serial não aparece em nenhum export.
**11.** Aplicar redação no `diagnosticsJSONL()`. Pronto quando: export de
diagnóstico não contém serial.
**12.** Adicionar `sendRaw(_ command: MicCommand)` ao `MicClient` (cliente do
microfone) e ao `MicSession`. Pronto quando: `send(_ setting:)` continua
passando nos testes.
**13.** Estender `FakeTransport` para responder a comandos crus. Pronto
quando: teste envia e recebe ACK (confirmação).
**14.** Criar `Scripts/verify.sh` com testes e build. Pronto quando: roda em
menos de 5 minutos.
**15.** Adicionar workflow de CI (integração contínua) no GitHub Actions.
Pronto quando: pipeline verde no primeiro push.

### Fase 1 — Presets e automação (passos 16–35)

**16.** Gerar `MicProfile` a partir do `DeviceSnapshot` (instantâneo do
dispositivo). Pronto quando: “Current settings” reflete o estado real.
**17.** Implementar `apply(_ profile:)` sequencial com ACK (confirmação).
Pronto quando: aplica 8 ajustes em ordem.
**18.** Abortar no primeiro `0xff` (rejeição) e registrar qual falhou. Pronto
quando: teste com rejeição interrompe a sequência.
**19.** Adicionar progresso e cancelamento na UI (interface do usuário). Pronto
quando: barra avança e cancelar para a aplicação.
**20.** Adicionar `isApplyingProfile` e desabilitar controles. Pronto quando:
usuário não consegue enviar comando concorrente.
**21.** Criar os presets Interview, Outdoor, Podcast, Music e Streaming. Pronto
quando: cada um aplica sem rejeição no hardware.
**22.** Adicionar seletor de preset no header. Pronto quando: aplica em um
clique.
**23.** Adicionar “Save current as preset”. Pronto quando: cria, nomeia e
persiste.
**24.** Adicionar importar e exportar JSON (JavaScript Object Notation). Pronto quando: ida e volta preserva
o perfil.
**25.** Separar bloco `broadcast` (difusão) do bloco por transmissor. Pronto
quando: perfil com TX1 (transmissor 1) e TX2 (transmissor 2) diferentes é
carregado sem mentir.
**26.** Testes de aborto, idempotência e ordem. Pronto quando: cobertura dos
três caminhos.
**27.** Adicionar preferência “Automation” (automação) desligada por padrão.
Pronto quando: persistida e respeitada.
**28.** Observar `NSWorkspace.didActivateApplicationNotification` (notificação
de ativação de aplicativo). Pronto quando: log registra troca de aplicativo.
**29.** Ignorar o próprio bundle (pacote) e o painel aberto. Pronto quando:
abrir o painel não aplica preset.
**30.** Implementar debounce (atraso de estabilização) de 400 milissegundos.
Pronto quando: alternância rápida não dispara múltiplas aplicações.
**31.** Criar UI (interface do usuário) de mapa aplicativo → preset. Pronto quando: associação
persistida.
**32.** Extrair a decisão de perfil para função pura e testar. Pronto quando:
teste cobre Zoom, OBS (Open Broadcaster Software) e app desconhecido.
**33.** Criar serviço de notificações com permissão sob demanda. Pronto quando:
permissão pedida só ao ligar o recurso.
**34.** Notificar bateria baixa em gauge (escala) 6. Pronto quando: uma única
notificação por 10 minutos.
**35.** Notificar desconexão e reconexão. Pronto quando: eventos não duplicam.

### Fase 2 — Valor no dispositivo (passos 36–60)

**36.** Criar `BatteryHistory` com gauge (escala) e timestamp (marca temporal).
Pronto quando: histórico persiste entre execuções.
**37.** Implementar estimador de taxa de descarga por estado. Pronto quando:
calcula minutos restantes com margem.
**38.** Exibir “~N min (estimativa)” no header. Pronto quando: não aparece
porcentagem.
**39.** Adicionar medição de latência de ACK (confirmação), jitter e perda.
Pronto quando: métricas aparecem no diagnóstico.
**40.** Implementar EWMA (média móvel ponderada exponencialmente) e CUSUM (soma
cumulativa). Pronto quando: alarme dispara em sessão simulada degradada.
**41.** Adicionar badge (indicador) de link (enlace) no header. Pronto quando:
três estados visíveis sem cor como única informação.
**42.** Notificar transição para degradado com rate limit (limite de
frequência). Pronto quando: no máximo uma por 5 minutos.
**43.** Validar `0x000A` por unidade no hardware. Pronto quando: TX1 (transmissor 1) e TX2 (transmissor 2)
piscam separadamente, ou o plano B é documentado.
**44.** Implementar Find my TX (transmissor) com 3 piscadas. Pronto quando: restaura o estado
anterior.
**45.** Restaurar LEDs ao desconectar. Pronto quando: desconectar no meio da
animação não deixa LED (diodo emissor de luz) apagado.
**46.** Adicionar confirmação antes de piscar transmissor em uso.
**47.** Adicionar toggle de iniciar ao fazer login com `SMAppService` (serviço
de gerenciamento de aplicativos). Pronto quando: estado real do sistema
exibido.
**48.** Adicionar preferência de barra de menus compacta.
**49.** Implementar label (rótulo) compacto com bateria e clipping (corte).
Pronto quando: atualiza sem animação contínua.
**50.** Adicionar atalhos locais para abrir painel e aplicar preset.
**51.** Adicionar atalhos globais com Carbon `RegisterEventHotKey` (registro de
tecla de atalho). Pronto quando: funciona sem permissão de Acessibilidade.
**52.** Criar UI (interface do usuário) de gravação de atalhos e detecção de conflito.
**53.** Implementar validação de esquema de backup na importação.
**54.** Criar relatório de restauração com aplicados, rejeitados e ignorados.
**55.** Testar que nenhum export contém serial.
**56.** Adicionar janela de Preferências com as seções de automação,
notificações, barra de menus e atalhos.
**57.** Adicionar onboarding (primeira configuração) em três telas.
**58.** Explicar no onboarding que NC (cancelamento de ruído) é físico.
**59.** Pedir permissão de microfone só ao ativar áudio.
**60.** Revisar strings em `en` (inglês) e `pt-BR` (português do Brasil) e rodar
o teste de paridade.

### Fase 3 — Áudio (passos 61–80)

**61.** Criar alvo `DJIMicAudio` no `Package.swift`.
**62.** Definir `AudioInputProviding` para testes sem hardware.
**63.** Implementar seleção de dispositivo com AUHAL (Audio Unit Hardware
Abstraction Layer).
**64.** Adicionar `NSMicrophoneUsageDescription` (descrição de uso do
microfone) e fluxo de permissão.
**65.** Implementar buffer circular de 30 segundos.
**66.** Calcular dBFS (decibéis relativos à escala máxima), RMS (valor eficaz)
e peak hold (retenção de pico).
**67.** Implementar contador de clipping (corte).
**68.** Desenhar medidor com `Canvas` (tela de desenho) a 20 Hz (hertz).
**69.** Implementar piso de ruído por *minimum statistics* (estatísticas de
mínimo).
**70.** Implementar VAD (detecção de atividade de voz).
**71.** Criar fluxo de sound check (verificação de som) de 10 segundos.
**72.** Implementar regra de sugestão de gain (ganho) e low cut (corte de
graves).
**73.** Adicionar botão “Apply suggestion” (aplicar sugestão).
**74.** Validar mapeamento de canais no hardware. Pronto quando: TX1 (transmissor 1) e TX2 (transmissor 2)
mapeados ou limitação documentada.
**75.** Implementar dominância por canal.
**76.** Implementar correlação cruzada para provar safety track (faixa de
segurança). Pronto quando: teste com fala real mede correlação e offset.
**77.** Implementar gravação com `AVAudioFile` (arquivo de áudio) fora do
render callback (retorno de renderização).
**78.** Adicionar nome de take (tomada), espaço em disco e aviso de volume de
rede.
**79.** Implementar monitoramento com aviso de realimentação.
**80.** Implementar troca de entrada padrão com restauração por UID
(identificador único).

### Fase 4 — Meta, pesquisa e distribuição (passos 81–100)

**81.** Criar `FrameInspector` (inspetor de quadros).
**82.** Adicionar buffer de ~5.000 frames (quadros).
**83.** Adicionar filtros, busca e export JSONL (JSON Lines, linhas no formato
JSON).
**84.** Liberar envio cru atrás de modo desenvolvedor com denylist (lista de
bloqueio).
**85.** Adicionar comparação de capturas por byte.
**86.** Criar ferramenta offline de MI (informação mútua) para triagem de bytes.
**87.** Criar ferramenta de ANOVA (análise de variância) por byte.
**88.** Criar harness (arcabouço) de teste de comandos com verificação por
áudio.
**89.** Decodificar os frames (quadros) `5b 04`.
**90.** Criar target (alvo) `djimic` de CLI (interface de linha de comando).
**91.** Implementar `djimic status --json` e `djimic preset`.
**92.** Implementar URL scheme (esquema de URL) `djimic://`.
**93.** Detectar app aberto e rotear sem abrir segunda sessão.
**94.** Migrar o empacotamento para projeto Xcode, se P1 e P3 forem mantidos.
**95.** Implementar App Intents (intenções do aplicativo).
**96.** Implementar notarização com `notarytool` e `stapler`.
**97.** Implementar manifesto de atualização com Ed25519 e verificação de
assinatura.
**98.** Generalizar o teste de paridade de localização para todos os idiomas.
**99.** Fazer auditoria de acessibilidade com VoiceOver e teclado.
**100.** Criar checklist de release e revisar as métricas de ganho.

---

## 7. Como usar no dia a dia

### Entrevista

1. Conectar o receptor; o app inicia no login.
2. Ao abrir o Zoom, o perfil Interview é aplicado.
3. O medidor mostra nível saudável e nenhum clipping (corte).
4. A bateria mostra “~2 h restantes”.
5. Se o link (enlace) degradar, o app avisa antes da falha.

### Transmissão

1. Abrir o OBS (Open Broadcaster Software); o perfil Streaming entra.
2. Usar o atalho global para aplicar o preset se o app não detectar.
3. A barra de menus compacta mostra clipping (corte) e conexão.
4. O CLI (interface de linha de comando) ou o Stream Deck dispara o preset na
   troca de cena.

### Gravação

1. Rodar o sound check (verificação de som) e aplicar a sugestão.
2. Ligar safety track (faixa de segurança).
3. Gravar com nome de take (tomada) automático.
4. Ao final, conferir o log (registro) de picos e clipping (corte).

### Viagem ou escritório

1. Usar Find my TX (encontrar transmissor) para localizar a unidade.
2. Importar o backup de configuração na máquina nova.
3. O app já abre com os presets e o mapa de aplicativos.

---

## 8. Como medir o ganho de forma honesta

| Indicador | Como coletar | Meta inicial |
|---|---|---|
| Tempo até pronto | Cronômetro em 5 sessões | −70% com presets |
| Ajustes manuais por sessão | Contador no `TelemetryRecorder` | ≤ 1 |
| Takes perdidos por bateria | Relato do usuário | 0 |
| Takes com clipping (corte) sem aviso | Relatório de gravação | 0 |
| Quedas de link (enlace) por hora | `LinkMonitor` | −50% |
| Falsos positivos de alerta | Contador de notificações | < 1 por sessão |
| Tempo para encontrar o transmissor | Cronômetro | < 30 s |
| Tempo para configurar máquina nova | Cronômetro | < 2 min |
| Regressões por release | CI (integração contínua) | 0 |

Regras de medição:

- Medir antes e depois, com a mesma pessoa e o mesmo kit.
- Não comparar sessões de naturezas diferentes.
- Registrar a versão do app e do firmware em cada medição.
- Se o ganho não aparecer em duas semanas, reavaliar a ideia.

---

## 9. O que não gera ganho

- Mais um controle na UI (interface do usuário) sem remover trabalho.
- Porcentagem de bateria inventada.
- Número de RSSI (indicador de intensidade do sinal recebido) sem evidência.
- Automação agressiva de gain (ganho) durante fala ao vivo.
- Modelo de aprendizado de máquina que o usuário não entende.
- Notificação a cada mudança de estado.
- Atualização automática antes de assinatura e notarização.
- Recurso que exige o usuário abrir o painel para descobrir que existe.

---

## 10. Checklist de aceite por ganho

- [ ] O ganho tem indicador e linha de base.
- [ ] O caminho principal funciona em 1–3 cliques.
- [ ] Existe estado de erro claro e reversível.
- [ ] Nenhum comando é considerado sucesso sem ACK (confirmação).
- [ ] O estado do dispositivo continua sendo a fonte da verdade.
- [ ] Não há serial em log (registro) exportável.
- [ ] Strings existem em `en` (inglês) e `pt-BR` (português do Brasil).
- [ ] Funciona em tema claro e escuro.
- [ ] Respeita Reduce Motion (redução de movimento).
- [ ] VoiceOver descreve o controle e o valor.
- [ ] Teste automatizado cobre a lógica pura.
- [ ] O ganho foi medido em pelo menos duas sessões reais.
