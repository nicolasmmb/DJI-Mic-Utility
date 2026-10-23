# Plano de evolução — DJI Mic Control

Documento consolidado de planejamento. Substitui o backlog de
[`feature-ideas.md`](feature-ideas.md), que fica como histórico. Aqui está a
viabilidade de cada ideia, a forma de implementação, as correções necessárias,
as ideias de dados e aprendizado de máquina, as validações de hardware
pendentes e o roteiro revisado.

Documentos relacionados:

- [`swift-app.md`](swift-app.md) — arquitetura e build do aplicativo atual
- [`protocol-notes.md`](protocol-notes.md) — protocolo USB (Universal Serial
  Bus) já validado
- [`feature-matrix.md`](feature-matrix.md) — o que já funciona no hardware
- [`feature-ideas.md`](feature-ideas.md) — backlog original

Convenção deste documento: toda sigla aparece expandida em parênteses. O
glossário completo está na seção 14.

---

## 1. Contexto e restrições

O aplicativo já controla o receptor e o transmissor por USB (Universal Serial
Bus) bulk, interface 6, e lê identidade, status, bateria e nível. O protocolo
é DUML (DJI Universal Markup Language) versão 2, reimplementado internamente.

Restrições atuais:

- **NC (cancelamento de ruído) é somente leitura** no Mic Mini 2; o estado vem
  da chave física O/L/H do receptor.
- **Bateria do TX (transmissor) é um gauge (escala) de 7 níveis**, não
  porcentagem.
- A interface 6 fica em uso exclusivo enquanto o aplicativo está aberto.
- O aplicativo é distribuído fora da App Store (loja de aplicativos da Apple);
  sandbox (isolamento) não é compatível com o acesso USB (Universal Serial Bus) atual.
- Sem dependências de terceiros no aplicativo. Tudo que for usado deve ser
  implementado no projeto ou vir de frameworks do sistema.
- Toda escrita USB (Universal Serial Bus) precisa de ACK (confirmação) `0x00`; `0xff` é rejeição.
- Toda nova string precisa existir em `en` (inglês) e `pt-BR` (português do
  Brasil).
- Novas views (telas) precisam funcionar em tema claro/escuro e com Reduce
  Motion (redução de movimento).
- O POC (proof of concept, prova de conceito) em Python e o aplicativo não
  podem abrir a interface 6 ao mesmo tempo.

---

## 2. Lacunas de plataforma (Fase 0)

Estas lacunas não são funcionalidades, mas bloqueiam várias delas. Devem ser
resolvidas antes do primeiro quick win (ganho rápido).

### 2.1 Persistência e perfis

Não existe `UserDefaults` (preferências do usuário) nem Application Support
(diretório de suporte do aplicativo) no projeto.

Criar:

```swift
public struct MicProfile: Codable, Identifiable {
    public var schema: Int = 1
    public var id: UUID
    public var name: String
    public var symbol: String
    public var receiver: ReceiverProfile
    public var transmitters: [String: TransmitterProfile]
}
```

Regras:

- `MicProfile` e seus componentes são DTOs (objetos de transferência de dados)
  próprios. `MicSetting` não deve virar `Codable`, porque carrega
  `CommandTarget` (alvo de comando), que não deve fazer parte do formato de
  arquivo.
- Preferências simples em `UserDefaults` com prefixo `com.niko.djimic.`.
- Perfis em
  `~/Library/Application Support/com.niko.djimic/profiles.json`, no formato
  JSON (JavaScript Object Notation).
- Validação de faixas ao carregar; chaves desconhecidas são ignoradas; `schema`
  versionado.
- Nunca gravar serial completo em arquivo exportável ou log (registro).

### 2.2 `AppServices` e `AppDelegate`

Hoje `AppModel` é criado direto no `@main`, e não há delegado do aplicativo.
Isso bloqueia notificações, atalhos globais, URL scheme (esquema de URL) e
janela de preferências.

Criar:

- `AppServices`: dono único da `MicSession` (sessão do microfone), do
  `ProfileStore` (armazenamento de perfis), do `PreferencesStore`
  (armazenamento de preferências), do serviço de notificações e do serviço de
  áudio.
- `AppDelegate` via `NSApplicationDelegateAdaptor` para instalar o
  `UNUserNotificationCenterDelegate` (delegado do centro de notificações do
  usuário) e tratar Apple Events (eventos da Apple).
- Regra: nenhuma segunda sessão USB (Universal Serial Bus). CLI (interface de linha de comando),
  URL scheme (esquema de URL) e App Intents (intenções do aplicativo) entregam
  comandos ao dono único.

### 2.3 Módulo de áudio

Criar `DJIMicAudio` com:

- protocolo `AudioInputProviding` (fornecimento de entrada de áudio) para
  testes sem hardware;
- seleção explícita do dispositivo de entrada, não o padrão do sistema;
- captura em 48 kHz (quilohertz), 2 canais, e buffer circular;
- features (variáveis) de áudio calculadas em 10–30 Hz (hertz).

Detalhe técnico: `AVAudioEngine.inputNode` usa o dispositivo padrão. Para
fixar o receptor:

```swift
var deviceID = /* AudioDeviceID (identificador do dispositivo de áudio) do receptor */
AudioUnitSetProperty(engine.inputNode.audioUnit!,
                     kAudioOutputUnitProperty_CurrentDevice,
                     kAudioUnitScope_Global, 0,
                     &deviceID, UInt32(MemoryLayout<AudioDeviceID>.size))
```

Alternativa: AUHAL (Audio Unit Hardware Abstraction Layer) puro, com
`kAudioUnitSubType_HALOutput`.

Permissão:

- `NSMicrophoneUsageDescription` (descrição de uso do microfone) no
  `Info.plist`.
- `AVCaptureDevice.requestAccess(for: .audio)` no momento em que o recurso de
  áudio for ativado, nunca no primeiro launch (primeira execução).
- A assinatura ad-hoc atual faz a permissão TCC (Transparency, Consent, and
  Control) resetar a cada build. Resolver junto com 2.5.

### 2.4 Envio cru de comandos

`MicSession.send` só aceita `MicSetting`. Para o Protocol Lab (laboratório de
protocolo) e para toda a pesquisa, extrair:

```swift
public func sendRaw(_ command: MicCommand) async throws
```

`send(_ setting:)` passa a delegar para `sendRaw(setting.command)`. Adicionar
também ao protocolo `MicClient` (cliente do microfone).

### 2.5 Assinatura estável

Hoje o build usa `codesign --sign -` (assinatura ad-hoc). Consequências:

- permissão de microfone e notificações podem ser revalidadas a cada build;
- `SMAppService` (serviço de gerenciamento de aplicativos) pode recusar o
  registro de início automático;
- notarização é impossível.

Ações:

- aceitar `SIGN_IDENTITY` (identidade de assinatura) no script de build;
- assinar cada bundle (pacote) separadamente, sem `--deep` (profundo);
- obter Developer ID (identificador de desenvolvedor) antes de Q5 e P4.

### 2.6 Projeto Xcode

O build é SPM (Swift Package Manager) puro. Isso bloqueia:

- P1 (App Intents), porque `appintentsmetadataprocessor` (processador de
  metadados de intenções) é executado pelo sistema de build do Xcode;
- P3 (Control Center, central de controle), que exige target de extensão
  (alvo de extensão).

Decisão pendente: migrar o empacotamento para um projeto Xcode mantendo o
`Package.swift` como definição dos módulos, ou aceitar que P1 e P3 ficam fora
do escopo.

---

## 3. Matriz de viabilidade

Legenda dos prefixos: **Q** = quick win (ganho rápido); **A** = audio
(áudio); **R** = research (pesquisa); **P** = product (produto); **U** = UX
(experiência do usuário).

Legenda de veredito:

- **Viável** — caminho claro, sem incógnita de hardware.
- **Ressalvas** — viável, mas depende de validação, permissão ou assinatura.
- **Pesquisa** — depende de descoberta no protocolo; sem garantia.
- **Não aplicável** — o hardware atual não oferece o recurso.

Legenda de prioridade: P0 (prioridade 0) bloqueador; P1 (prioridade 1) alto
retorno; P2 (prioridade 2) diferencial; P3 (prioridade 3) pesquisa; P4
(prioridade 4) dependente de API (interface de programação de aplicações) ou
produto maduro.

| ID (identificador) | Funcionalidade | Veredito | Esforço | Dependência | Prioridade |
|---|---|---|---|---|---|
| Q1 | Presets (predefinições) | Viável | 2–3 dias | 2.1 | P0 |
| Q2 | Perfil por aplicativo | Viável | 1,5–2 dias | 2.1, 2.2 | P0 |
| Q3 | Notificações de estado | Ressalvas | 1,5–2 dias | 2.2 | P0 |
| Q4 | Find my TX (encontrar transmissor) | Ressalvas | 0,5–1 dia | `0x0A` por unidade | P1 |
| Q5 | Launch at login (iniciar ao fazer login) | Ressalvas | 0,5 dia | 2.5 | P1 |
| Q6 | Backup/restore (cópia e restauração) | Viável | 1–1,5 dia | 2.1 | P1 |
| Q7 | Sound check (verificação de som) | Ressalvas | 3–4 dias | 2.3 | P1 |
| Q8 | Atalhos de teclado | Viável | 1,5–2 dias | 2.1, 2.2 | P2 |
| Q9 | Menu bar compacto (barra de menus) | Viável | 0,5–1 dia | — | P2 |
| A1 | Medidor profissional | Viável | 2–3 dias | 2.3 | P1 |
| A2 | Monitoramento de áudio | Viável | 2 dias | 2.3 | P2 |
| A3 | Gravação com safety track (faixa de segurança) | Ressalvas | 3–4 dias | 2.3 + validação | P2 |
| A4 | Auto-gain (ganho automático) | Ressalvas | 2–3 dias | 2.3 + validação | P2 |
| A5 | Troca automática de input (entrada) | Viável | 1 dia | — | P2 |
| R1 | Mute (silenciamento) | Pesquisa | 2–5 dias | captura externa | P2 |
| R2 | Qualidade de link e RSSI (indicador de intensidade do sinal recebido) | Pesquisa | 1–3 dias | frames `5b 04` | P3 |
| R3 | Bateria em porcentagem via BLE (Bluetooth Low Energy) | Não aplicável/Pesquisa | 0,5 dia para decidir | topologia | P3 |
| R4 | Gravação interna e 32-bit float (ponto flutuante de 32 bits) | Não aplicável no Mini 2 | 0,5 dia para confirmar | hardware 2S | P3 |
| R5 | Pairing (pareamento) | Pesquisa | 3–5 dias | captura externa | P3 |
| R6 | Protocol Lab (laboratório de protocolo) | Viável | 3–4 dias | 2.4 | P1 |
| P1 | App Intents (intenções do aplicativo) | Ressalvas | 2–3 dias + Xcode | 2.6 | P1 |
| P2 | URL scheme e CLI (esquema de URL e linha de comando) | Viável | 1–2 dias | 2.2 | P2 |
| P3 | Control Center (central de controle) | Ressalvas | 4–6 dias | 2.6, macOS 15+ | P4 |
| P4 | Notarização e assinatura | Viável | 1 dia | conta Apple | P1 |
| P5 | Atualização automática | Ressalvas | 3–4 dias | 2.5 | P3 |
| P6 | CI (integração contínua) macOS | Viável | 0,5 dia | — | P1 |
| P7 | Mais idiomas | Viável | 1–2 dias | — | P3 |
| U1 | Onboarding (primeira configuração) | Viável | 1 dia | 2.1 | P1 |
| U2 | Acessibilidade | Viável | 2–3 dias | — | P2 |
| U3 | Diagnóstico de erros | Ressalvas | 0,5–1 dia | redação de serial | P1 |
| U4 | Estado vazio e reconexão | Viável | 0,5 dia | — | P2 |
| U5 | Preferências | Viável | 1–2 dias | 2.1 | P1 |

---

## 4. Quick wins (ganhos rápidos)

### Q1 — Presets (predefinições)

**Objetivo:** aplicar um conjunto de ajustes com um clique.

**Implementação:**

- `MicProfile` + `ProfileStore` (seção 2.1).
- Aplicação sequencial com ACK (confirmação) por comando:

```swift
public func apply(_ profile: MicProfile) async -> ApplyReport
```

- `ApplyReport` contém: comandos aplicados, rejeitados, ignorados por já
  estarem no valor desejado e o erro que interrompeu.
- Abortar no primeiro `0xff` (rejeição) e mostrar qual ajuste falhou.
- Barra de progresso e botão cancelar. Timeout atual de 2 segundos por comando:
  um preset de 8 ajustes pode levar 16 segundos no pior caso.
- Estado `isApplyingProfile` que desabilita os controles durante a aplicação.
  Sem isso, o preset e o usuário disputam o mesmo `SettingID` (identificador
  de ajuste) em `pendingSettings`.
- “Current settings” (configurações atuais) é gerado a partir do
  `DeviceSnapshot` (instantâneo do dispositivo).
- Importar/exportar JSON (JavaScript Object Notation).
- Não incluir NC (cancelamento de ruído) no preset.

**Limitação estrutural:** `lowCut` (corte de graves), `micLED` (LED (diodo emissor de luz) do
microfone) e `autoOffTX` (desligamento automático do transmissor) usam target
(alvo) broadcast (difusão para todos os transmissores). Só `voiceTone` (tom de
voz) é por unidade. Se TX1 (transmissor 1) e TX2 (transmissor 2) estiverem com
valores diferentes, o preset não consegue restaurar ambos. O modelo de dados
precisa refletir isso: um bloco `broadcast` e um bloco por unidade.

**Testes:** round-trip de JSON (JavaScript Object Notation), ordem dos comandos, aborto em rejeição, preset
aplicado com transporte falso (fake transport), idempotência.

### Q2 — Perfil automático por aplicativo

**Implementação:**

- `NSWorkspace.shared.notificationCenter` com
  `didActivateApplicationNotification` (notificação de ativação de
  aplicativo).
- Mapear `bundleIdentifier` (identificador de pacote) para ID (identificador) de perfil.
- Debounce (atraso de estabilização) de 300–500 ms (milissegundos) com `Task`
  cancelável.
- Ignorar o próprio bundle `com.niko.djimic`: abrir o painel gera uma
  notificação de ativação.
- Flag “painel aberto” via `onAppear`/`onDisappear` do `MenuBarPanel` (painel
  da barra de menus). Validar que esses callbacks disparam de fato no
  `MenuBarExtra`.
- Opção global “Automation” (automação) desligada por padrão.
- Registrar no diagnóstico qual perfil foi aplicado e por quê.
- Nunca aplicar perfil enquanto o painel estiver aberto ou durante uma
  aplicação em andamento.

**Teste:** extrair a decisão “qual perfil aplicar” para uma função pura e
testar com uma lista de eventos.

### Q3 — Notificações de estado

**Implementação:**

- `UNUserNotificationCenter` (centro de notificações do usuário), permissão
  pedida quando o usuário liga o recurso.
- `UNNotificationCategory` (categoria) e `UNNotificationAction` (ação):
  “Abrir painel”, “Reconectar”.
- Rate limit (limite de frequência) por tipo, por exemplo uma notificação de
  bateria a cada 10 minutos.
- Detectar mudança de NC (cancelamento de ruído) comparando snapshots
  consecutivos.
- Preferência por tipo de notificação.

**Correção importante:** não existe evento de clipping (corte) no protocolo.
O byte `payload[37] & 0x10` é o *ajuste* Clipping Control (controle de corte),
não um indicador de corte ocorrido. Notificação de clipping só é possível com
o medidor de áudio (A1) ou inferindo saturação de `inputLevel` (nível de
entrada), que não está calibrado.

### Q4 — Find my TX (encontrar transmissor)

**Implementação:**

- Alternar o LED (diodo emissor de luz) do transmissor com o comando `0x000A`,
  valores `0` (ligado) e `2` (desligado), 3–4 vezes.
- Esperar o status refletir `ledsOff` antes de cada alternância, em vez de usar
  espera fixa.
- Restaurar o estado anterior com `defer` (execução garantida na saída) e
  também em caso de desconexão.
- Desabilitar o botão durante a animação.
- Com dois transmissores, permitir escolher TX1 (transmissor 1) ou TX2
  (transmissor 2).

**Pendência de hardware:** `0x000A` foi validado apenas com target (alvo)
`0xFFFF` (broadcast, difusão). Validar se `0x0001` e `0x0002` são aceitos. Se
não forem, o recurso só existe em modo “todos os transmissores”.

**Cuidado:** o LED (diodo emissor de luz) é também um ajuste do usuário. Uma animação interrompida
não pode deixar os LEDs desligados.

### Q5 — Launch at login (iniciar ao fazer login)

**Implementação:**

- `SMAppService.mainApp.register()` e `unregister()`.
- Mostrar `SMAppService.mainApp.status` (estado real do sistema), não apenas
  uma preferência local.
- Ações para `requiresApproval` (requer aprovação) e
  `openSystemSettingsLoginItems()` (abrir itens de login nas configurações).
- Requer aplicativo assinado e em `/Applications` (diretório de aplicativos).
  Na prática depende de P4.

### Q6 — Backup e restauração

**Implementação:**

- Reutilizar `MicProfile` com `schema` (versão do esquema) e `createdAt`
  (data de criação).
- Restauração com confirmação e relatório de comandos aplicados, rejeitados e
  ignorados.
- Ignorar NC (cancelamento de ruído).
- Validar faixas antes de aplicar.
- Não incluir serial completo.
- Tratar `autoOff` (desligamento automático), `lowCut` (corte de graves) e
  `micLED` (LED (diodo emissor de luz) do microfone) como broadcast (difusão), não por unidade.

### Q7 — Sound check (verificação de som)

**Implementação:**

- `AVAudioEngine` (motor de áudio) capturando a entrada USB (Universal Serial Bus) do receptor.
- Medir por 10 segundos: peak (pico), RMS (Root Mean Square, valor eficaz),
  dBFS (decibéis relativos à escala máxima), piso de ruído por percentil e
  clipping (corte).
- Sugerir gain (ganho), low cut (corte de graves) e posição do microfone.
- Botão “Apply suggestion” (aplicar sugestão); nunca automático.
- Exigir `NSMicrophoneUsageDescription` e permissão.

**Ressalva:** a sugestão é heurística. “Posição do microfone” não é mensurável
pelo sinal; transformar em dica genérica ou remover. Não prometer redução de
ruído: NC (cancelamento de ruído) é físico.

### Q8 — Atalhos de teclado

**Implementação:**

- Atalhos locais com `Commands` e `keyboardShortcut` (atalho de teclado); só
  funcionam com o aplicativo em foco.
- Atalhos globais com Carbon `RegisterEventHotKey` (registro de tecla de
  atalho). Carbon **não** exige permissão de Acessibilidade; apenas
  `NSEvent.addGlobalMonitorForEvents` (monitor global de eventos) exige.
- Preferências para gravar e alterar atalhos, persistidas em `UserDefaults`.
- Desregistrar no `deinit` e detectar conflito.

### Q9 — Menu bar compacto (barra de menus)

**Implementação:**

- Label (rótulo) customizado no `MenuBarExtra` com `HStack` (pilha horizontal):
  ícone, bateria baixa e ponto de clipping.
- O `MicSession` já deduplica snapshots (instantâneos), então o custo de
  atualização é baixo.
- Atualizar só quando o valor mudar; não usar `TimelineView` (visão de linha
  do tempo) nem animação contínua.
- Preferência “Compact menu bar” (barra de menus compacta).

---

## 5. Áudio profissional

### A1 — Medidor profissional

**Implementação:**

- `DJIMicAudio` (seção 2.3) com buffer circular de 30 segundos.
- Métricas: dBFS (decibéis relativos à escala máxima), peak hold (retenção de
  pico), clip count (contagem de cortes), RMS (valor eficaz), crest factor
  (fator de crista) e histórico de 30 segundos.
- Desenho com SwiftUI `Canvas` (tela de desenho) a 15–30 Hz (hertz).
- `Clip count` por amostra em ±1,0; opcionalmente pico entre amostras via
  sobreamostragem 4x e FIR (filtro de resposta ao impulso finita).

**Ressalva:** o USB (Universal Serial Bus) entrega um stream (fluxo) estéreo, não dois medidores
independentes. “Sparkline (minigráfico) por TX (transmissor)” só faz sentido
em stereo (estéreo), com canal 0 para TX1 (transmissor 1) e canal 1 para TX2
(transmissor 2). O mapeamento precisa ser validado.

### A2 — Monitoramento de áudio

**Implementação:**

- Rotear entrada para saída com `AVAudioEngine`, com buffer separado do gain
  de monitoramento do dispositivo.
- Controle de volume próprio.
- Aviso de realimentação; exigir fones quando a saída for alto-falante
  embutido.
- Desligar ao trocar de dispositivo de saída.
- Nunca ativar automaticamente.

### A3 — Gravação com safety track (faixa de segurança)

**Pré-requisito:** validar o mapeamento de canais (seção 11).

**Implementação:**

- `AVAudioFile` (arquivo de áudio) em WAV (Waveform Audio File Format) ou CAF
  (Core Audio Format).
- Escrita fora do render callback (retorno de renderização): buffer circular +
  task (tarefa) de escrita.
- Nome automático: data, preset e take (tomada).
- Se safety track estiver ativo, dois arquivos ou um arquivo com duas faixas.
- Log de peak (pico) e clipping (corte) por take.
- Indicador de espaço em disco; aviso para volume de rede.
- Nunca apagar arquivos automaticamente.

**Pergunta que decide o valor do recurso:** em mono + safety track, o canal 2
do USB (Universal Serial Bus) contém uma cópia atenuada do canal 1? Se contiver, A3 é valioso. Se
não, é apenas gravação estéreo comum.

### A4 — Auto-gain (ganho automático)

**Pré-requisito:** validar a faixa e o passo de gain aceitos pelo hardware
(seção 11).

**Implementação:**

- Modo “Suggest” (sugerir) e modo “Auto” (automático com opt-in).
- Controlador PI (proporcional-integral) com deadband (faixa morta) de 3 dB
  (decibéis), limite de um passo a cada 2 segundos e anti-windup (proteção
  contra acúmulo).
- Histerese para evitar comandos em loop.
- Suspender ao usuário mexer no slider (controle deslizante).
- Respeitar Clipping Control (controle de corte).
- Registrar cada ajuste no diagnóstico.

**Aviso:** nunca aplicar ganho durante uma fala importante sem aviso. A UI
(interface do usuário) atual oferece `[-12, -6, 0, 6, 12]`, mas o protocolo é
`int8` (inteiro de 8 bits com sinal); validar o que o dispositivo aceita.

### A5 — Troca automática de entrada padrão

**Implementação:**

- `kAudioHardwarePropertyDefaultInputDevice` (propriedade de dispositivo de
  entrada padrão) para ler e escrever o dispositivo padrão.
- Guardar o **UID (identificador único)** do dispositivo anterior, não o
  `AudioDeviceID` (identificador de dispositivo de áudio), que pode ser
  reciclado.
- Ao conectar o receptor, torná-lo entrada padrão; ao desconectar, restaurar
  somente se o padrão atual ainda for o receptor.
- Preferência “Set as default input” (definir como entrada padrão).
- Observar `kAudioHardwarePropertyDevices` (propriedade de dispositivos) para
  reagir a mudanças.

---

## 6. Engenharia reversa e recursos avançados

### R1 — Mute (silenciamento)

**Status:** comando não descoberto.

**Bloqueio real:** não existe aplicativo oficial para macOS. A captura exige
analisador USB (Universal Serial Bus) no link ou `usbmon` (monitor de USB (Universal Serial Bus)) no Linux com o aplicativo
Android.

**Abordagem:**

1. Capturar o tráfego ao mutar pelo aplicativo oficial.
2. Em paralelo, testar candidatos com valores `0`/`1`, target (alvo)
   `0x0001`/`0x0002`, um por vez.
3. Validar com ACK (confirmação), mudança de status e **áudio**: se o RMS
   (valor eficaz) cair mais de 20 dB (decibéis) em 300 ms (milissegundos) e
   voltar ao reverter, o candidato é provavelmente mute.
4. Reverter sempre; parar em qualquer anomalia.

**Não fazer:** implementar mute abaixando o gain (ganho) ao mínimo. Isso altera
a configuração do usuário e não silencia de verdade.

### R2 — Qualidade de link e RSSI (indicador de intensidade do sinal recebido)

**Status:** existem bytes desconhecidos no status.

**Abordagem:**

1. Decodificar primeiro os frames (quadros) `5b 04` que hoje são ignorados.
   Eles podem carregar telemetria de link (enlace).
2. Caminhar com o transmissor a distâncias conhecidas e capturar o status.
3. Triagem de bytes por MI (informação mútua) e por variância explicada.
4. Testar monotonicidade byte → distância com regressão isotônica.
5. Se não houver RSSI (indicador de intensidade do sinal recebido), usar perda de pacotes e jitter como proxy (aproximação).

**Não fazer:** exibir um número de RSSI (indicador de intensidade do sinal recebido) sem evidência física.

### R3 — Bateria em porcentagem via BLE (Bluetooth Low Energy)

**Status:** não investigado.

**Abordagem em 30 minutos:** com o kit ligado, verificar se o transmissor
anuncia BLE (Bluetooth Low Energy). A topologia documentada é transmissor → receptor em 2,4 GHz
(gigahertz) proprietário; o celular fala com o **receptor** por USB (Universal Serial Bus)-C.

- Se o transmissor não anunciar, encerrar o item.
- Se anunciar, procurar Battery Service (`0x180F`) e característica
  `0x2A19`.
- Manter o gauge (escala) USB (Universal Serial Bus) como fallback (alternativa).

**Cuidado:** BLE (Bluetooth Low Energy) e USB (Universal Serial Bus) podem não coexistir em todos os modos; permissão de
Bluetooth é necessária.

### R4 — Gravação interna e 32-bit float (ponto flutuante de 32 bits)

**Status:** recurso do Mic Mini 2S; o Mini 2 provavelmente não tem.

**Abordagem:** confirmar no manual e na identidade do dispositivo. Se existir,
gate (restrição condicional) por `productName` (nome do produto) e firmware, e
não mostrar UI (interface do usuário) quando não houver suporte.

### R5 — Pairing (pareamento)

**Status:** comandos não explorados.

**Abordagem:** capturar o linking (vinculação) pelo aplicativo oficial, mapear
comandos e estados, e só implementar com recovery (recuperação) claro pelo
botão físico. Alto risco de deixar o kit sem link.

### R6 — Protocol Lab (laboratório de protocolo)

**Implementação:**

- `MicSession.sendRaw` (seção 2.4).
- `FrameInspector` (inspetor de quadros) sobre `ParsedFrame` (quadro
  analisado): target (alvo), command (comando), payload (carga útil), CRC
  (verificação de redundância cíclica), sequência e latência de ACK
  (confirmação).
- Buffer circular de ~5.000 frames (quadros) com timestamp (marca temporal).
- Filtros por tipo, ID (identificador) e target (alvo), busca e export JSONL
  (JSON Lines, linhas no formato JSON (JavaScript Object Notation)).
- Envio cru protegido por “Developer mode” (modo desenvolvedor), confirmação
  digitada e denylist (lista de bloqueio) de comandos perigosos: `0x20`,
  `0x23`, reset (reinício), formatação e firmware.
- Replay (reprodução): frames de leitura por padrão; comandos exigem
  confirmação por frame (quadro).
- Comparação de capturas: alinhar duas sessões e mostrar diferenças por byte.

**Valor:** é o item de maior alavancagem. Desbloqueia R1, R2, R4 e R5.

---

## 7. Produto, integrações e distribuição

### P1 — App Intents (intenções do aplicativo)

**Implementação:**

- `AppServices.shared` como estado compartilhado.
- Intenções: aplicar preset (predefinição), definir gain (ganho), encontrar
  transmissor, abrir painel.
- `AppEntity` (entidade do aplicativo) e `EntityQuery` (consulta de entidade)
  para perfis.
- `AppShortcutsProvider` (provedor de atalhos do aplicativo).
- Intenções assíncronas que aguardam conexão com timeout (tempo limite).

**Bloqueios:**

1. SPM (Swift Package Manager) não executa `appintentsmetadataprocessor`
   (processador de metadados de intenções). Sem projeto Xcode, o Shortcuts
   (Atalhos) pode não listar as ações.
2. `MenuBarExtra` não tem API (interface de programação de aplicações) pública para abrir o painel programaticamente.
   “Show Mic Panel” (mostrar painel) precisa abrir uma janela normal com o
   mesmo conteúdo.

### P2 — URL scheme e CLI (esquema de URL e linha de comando)

**Implementação:**

- `CFBundleURLTypes` (tipos de URL do pacote) e tratamento de Apple Event
  (evento da Apple) no `AppDelegate`.
- `djimic://preset/outdoor`, `djimic://gain/6`.
- Target (alvo) executável `djimic` reutilizando `DJIMicSession` (sessão do
  microfone): `status`, `preset`, `gain`, `monitor`.
- Saída `--json` (JavaScript Object Notation) e códigos de saída estáveis.
- Se o aplicativo estiver aberto, a interface 6 está ocupada: o CLI (interface
  de linha de comando) deve detectar isso e rotear por URL scheme (esquema de
  URL) ou falhar com mensagem clara. Nunca abrir uma segunda sessão.

### P3 — Control Center (central de controle)

**Implementação:** `ControlWidget` (widget de controle) com intenções para
aplicar preset e abrir o painel.

**Bloqueios:** exige macOS 15+ (versão 15 ou superior) e target de extensão
(alvo de extensão), que o SPM (Swift Package Manager) não gera. Não transmite nível em tempo real.
Valor baixo para o esforço; manter em P4 (prioridade 4).

### P4 — Notarização e assinatura

**Implementação:**

- Developer ID (identificador de desenvolvedor) Application (certificado de desenvolvedor da Apple).
- Hardened runtime (tempo de execução endurecido).
- Assinatura de cada bundle (pacote) separadamente; evitar `--deep`
  (profundo).
- `codesign --options runtime --timestamp` (opções de runtime e marca
  temporal).
- `xcrun notarytool submit --wait` (envio e espera da notarização).
- `xcrun stapler staple` (grampeamento do selo).
- Instruções de instalação sem Gatekeeper (porteiro do macOS).

Sem sandbox (isolamento) por causa do acesso USB (Universal Serial Bus). IOKit não exige entitlment
(direito) adicional fora do sandbox.

### P5 — Atualização automática

**Implementação:**

- Manifesto JSON (JavaScript Object Notation) de releases (versões).
- Assinatura Ed25519 (algoritmo de assinatura) verificada com `CryptoKit`
  (kit de criptografia).
- Download e verificação com `SecStaticCodeCheckValidity` (verificação de
  validade de código estático) e requirement (requisito) fixando o Team ID
  (identificador da equipe).
- Troca atômica via script após o quit (encerramento), com rollback
  (reversão).
- Canais stable (estável) e beta (teste).
- Sem Sparkle (framework de atualização) nem terceiros.

**Risco:** é security-sensitive (sensível à segurança). Uma verificação errada
pode instalar binário inválido. Fazer depois de P4.

### P6 — CI (integração contínua) macOS

**Implementação:**

- GitHub Actions com `macos-15`.
- `swift test`, build release (compilação final), `./Scripts/build-app.sh` e
  `uv run pytest`.
- Cache do diretório `.build`.
- **Ressalva:** `RenderTests` (testes de renderização) usam `NSApplication` e
  `ImageRenderer` (renderizador de imagem) e podem falhar em runner (executor)
  sem sessão gráfica. Condicionar a `CI` (integração contínua) ou rodar só localmente.

### P7 — Mais idiomas

**Implementação:**

- Adicionar `es` (espanhol), `fr` (francês), `de` (alemão), `ja` (japonês) e
  `zh` (chinês) em `Sources/DJIMicUI/Resources`.
- Atualizar `CFBundleLocalizations` (localizações do pacote).
- Generalizar `localizationKeysAreComplete` (teste de completude de chaves),
  que hoje compara apenas `en` (inglês) e `pt-BR` (português do Brasil).
- Revisar largura de controles em alemão e japonês.

---

## 8. UX (experiência do usuário), acessibilidade e qualidade

### U1 — Onboarding (primeira configuração)

- Explicar que NC (cancelamento de ruído) é chave física.
- Pedir permissão de microfone só quando o recurso de áudio for usado.
- Explicar por que o aplicativo ocupa a interface USB (Universal Serial Bus).
- Detectar dispositivo e mostrar “pronto”.
- Controle de “não mostrar novamente”.

### U2 — Acessibilidade

- VoiceOver completo em todos os controles, com `accessibilityValue` (valor de
  acessibilidade) em sliders (controles deslizantes) e toggles (alternadores).
- Navegação por teclado.
- Alto contraste.
- Reduce Motion (redução de movimento) e Reduce Transparency (redução de
  transparência).
- Não depender só de cor para status.

### U3 — Diagnóstico de erros

- Mensagens específicas por erro USB (Universal Serial Bus).
- Exportar log (registro) com versão do aplicativo, firmware e macOS.
- Botão “Copiar diagnóstico”.

**Correção necessária:** `AppModel.diagnosticsJSONL()` exporta frames (quadros)
crus em hexadecimal, e o frame de identidade contém o serial. Adicionar
redação antes de qualquer exportação ou cópia.

### U4 — Estado vazio e reconexão

- Placeholder (espaço reservado) claro quando não há transmissor.
- Banner (faixa) de reconexão sem bloquear o aplicativo.
- Última configuração conhecida esmaecida.

### U5 — Preferências

- Iniciar ao fazer login.
- Notificações.
- Barra de menus compacta.
- Atalhos.
- Presets (predefinições) e automação.
- Idioma.
- Diagnóstico.

Janela própria ou `Settings` (configurações) scene (cena), dependente da
persistência da seção 2.1.

---

## 9. Correções ao backlog original

1. **Perfil por TX (transmissor) não é possível** para `lowCut` (corte de
   graves), `micLED` (LED (diodo emissor de luz) do microfone), `autoOffTX` (desligamento automático)
   e `clipping` (corte): são broadcast (difusão) ou RX (receptor). Só
   `voiceTone` (tom de voz) é por unidade. O JSON (JavaScript Object Notation) de Q6, que mostra `autoOff`
   dentro de cada transmissor, não é restaurável fielmente.
2. **Q3 e clipping (corte)** — não há evento de clipping no protocolo; só o
   ajuste.
3. **A1 e “sparkline por TX (transmissor)”** — o USB (Universal Serial Bus) entrega um stream (fluxo) estéreo, não
   dois medidores independentes.
4. **Q8 e Acessibilidade** — Carbon não exige permissão; só monitores de
   `NSEvent` exigem.
5. **R3 e BLE (Bluetooth Low Energy)** — a topologia documentada não sugere
   BLE (Bluetooth Low Energy) no transmissor; validar antes de planejar.
6. **P1 e P3** — ambos esbarram no build por SPM (Swift Package Manager).
7. **Q5** — depende de P4 (notarização) na prática.
8. **A3** — o pressuposto “canal 2 = safety track (faixa de segurança)” é o
   item mais caro e não está validado.
9. **U1 a U5 não aparecem na matriz original**, apesar de a seção existir no
   documento. Aqui entram na matriz.
10. **U3** — o documento pede para não incluir serial, mas o export atual o
    inclui nos frames crus.
11. **Q4** — o comando `0x0A` foi validado só em broadcast (difusão), não por
    unidade.
12. **A4** — a faixa `[-12, -6, 0, 6, 12]` é da UI (interface do usuário), não do protocolo; o passo
    real precisa ser validado.

---

## 10. Dados e aprendizado de máquina

Esta seção responde à pergunta “que algoritmos dá para aplicar com os dados
que o aplicativo recebe?”. A conclusão principal: com um kit, dois
transmissores no máximo e status a ~10 Hz (hertz), o retorno vem primeiro de
processamento de sinais e estatística; aprendizado de máquina supervisionado
só depois de existir telemetria gravada e rótulos.

### 10.1 Inventário de dados

| Fonte | Taxa | Campos | Rótulo disponível |
|---|---|---|---|
| Push de status | ~10 Hz (hertz) | gain (ganho), monitoring gain (ganho de monitoramento), stereo (estéreo), safety (segurança), clipping (corte), auto-off (desligamento automático), NC (cancelamento de ruído), bateria em gauge (escala de 7 níveis), charging (carregando), low cut (corte de graves), leds (LEDs), voice tone (tom de voz), `inputLevel` (nível de entrada) | Só o que for anotado |
| Push de nível | ~10 Hz (hertz) | nível por transmissor | Nenhum |
| ACK (confirmação) | por comando | latência e aceito/rejeitado | Sim: resultado do comando |
| Frames (quadros) crus | contínuo | bytes desconhecidos, frames `5b 04` | Nenhum |
| Áudio USB (Universal Serial Bus) | 48 kHz (quilohertz) | 2 canais | Nenhum |
| Contexto do macOS | por evento | aplicativo em primeiro plano, hora | Parcial |
| Ações do usuário | por evento | ajuste alterado, preset aplicado | **Sim, e é o dado mais valioso** |

O log de ações do usuário é o único rótulo gratuito e confiável. É nele que
está o aprendizado de máquina viável hoje.

### 10.2 `TelemetryRecorder` (gravador de telemetria)

Pré-requisito para qualquer modelo. Sem isso, nenhuma ideia desta seção sai do
papel.

Formato JSONL (JSON Lines, linhas no formato JSON (JavaScript Object Notation)), uma linha por evento:

```json
{"t":"2026-10-22T18:04:11.231Z","kind":"snapshot","conn":"connected","rx":{"gain":6,"mon":0,"stereo":false,"safety":true,"clip":true,"autoOff":true,"nc":"basic"},"tx":[{"unit":1,"level":42,"bat":1,"charging":false,"lowCut":true,"tone":"regular"}],"app":"us.zoom.xos","ack":{"latencyMs":48}}
```

Campos recomendados:

- `t` (marca temporal ISO 8601, formato de data e hora).
- `kind`: `snapshot`, `level`, `ack`, `frame`, `userAction`, `profileApplied`,
  `audioFeatures`.
- `conn` (estado da conexão), `rx` (receptor), `tx` (transmissores), `app`
  (aplicativo em primeiro plano).
- `ack.latencyMs` (latência de confirmação em milissegundos) e
  `ack.result` (resultado).
- `unknownBytes` (bytes ainda não decodificados), para a engenharia reversa.
- `redacted` (indicador de que o serial foi removido).

Janelamento para modelos:

- Janela de 5 segundos, passo de 1 segundo.
- Agregações por janela: média, desvio padrão, mínimo, máximo, inclinação,
  p50/p95, contagem de eventos.
- Features de áudio calculadas a 10–30 Hz (hertz) e agregadas na mesma janela.

Privacidade:

- Áudio e serial nunca saem do Mac (computador da Apple).
- Export removendo serial e áudio por padrão.
- Dados de uso são locais; nada de telemetria remota sem opt-in explícito.

### 10.3 Algoritmos por área

#### Áudio e medidor (A1, Q7, A2)

Nada disso exige XGBoost (eXtreme Gradient Boosting):

- **Sonoridade perceptual:** filtro K-weighting (ponderação K) da ITU (União Internacional de Telecomunicações), recomendação
  BS.1770 →
  LUFS (unidades de sonoridade relativas à escala completa). Melhor que RMS
  (valor eficaz) cru para responder “está alto?”.
- **Piso de ruído:** *minimum statistics* (estatísticas de mínimo, algoritmo de
  Martin) ou percentil móvel de 10–20%. Estável mesmo com fala intermitente.
- **VAD (detecção de atividade de voz):** energia, ZCR (taxa de cruzamento por
  zero) e planicidade espectral. Se quiser aprendizado de máquina, uma
  regressão logística ou árvore de decisão de 20 nós sobre 6–8 features já
  supera regra fixa e continua auditável.
- **Clipping (corte) real:** sequências de amostras em ±1,0 e pico entre
  amostras via sobreamostragem 4x com FIR (filtro de resposta ao impulso
  finita).
- **Crest factor (fator de crista)** e correlação entre canais: detecta fala
  comprimida, microfone saturado e dominância de um transmissor.
- **Classificação fala/música/ruído:** features por banda + árvore pequena,
  para o sound check (verificação de som) não sugerir ganho com base em música
  ou ar-condicionado.

#### Auto-gain (A4)

- **Controlador PI (proporcional-integral)** com anti-windup (proteção contra
  acúmulo), deadband (faixa morta) de 3 dB (decibéis) e limite de um passo a
  cada 2 segundos. Resolve a maior parte do problema com comportamento
  previsível.
- **Filtro de Kalman 1D** no nível em dBFS (decibéis relativos à escala
  máxima) para separar fala de picos isolados.
- **Regressão isotônica** “nível medido → ganho escolhido pelo usuário”:
  monótona, explicável e minúscula. Precisa de ~50–200 decisões registradas.
- **Aprendizado por imitação** (imitation learning) das correções manuais: só
  depois de meses de uso. XGBoost (eXtreme Gradient Boosting) aqui é
  exagerado; uma tabela calibrada ganha.

#### Link e RSSI (R2)

- **EWMA (média móvel ponderada exponencialmente) + CUSUM (soma
  cumulativa):** detecta degradação gradual sem esperar queda total.

```
s_t = max(0, s_(t-1) + (x_t - μ0 - k))
alarme se s_t > h
```

- **HMM (modelo oculto de Markov) de 3 estados** (bom, degradado, perdido) com
  observáveis: taxa de ACK (confirmação), jitter de interchegada, variância do
  nível e perda de frames (quadros). Online via Viterbi.
- **Filtro de Kalman** fundindo latência de ACK (confirmação) e taxa de perda em um link
  score (pontuação de enlace).
- **XGBoost (eXtreme Gradient Boosting) para alerta preditivo:** features de
  uma janela de 5 segundos → rótulo “vai perder o link nos próximos 2
  segundos”. Rótulo fraco e automático, gerado pelo próprio timeout de ACK (confirmação).
  É o caso mais defensável de boosting no projeto.
- **Detecção de anomalia** por z-score em janela; Isolation Forest (floresta
  de isolamento) apenas offline para gerar rótulos.

#### Bateria (R3)

- **Modelo de taxa de descarga por estado:** regressão de “queda de gauge
  (escala) por hora” em função de NC (cancelamento de ruído), low cut (corte
  de graves), gravação, gain (ganho) e temperatura. Regressão linear ou
  XGBoost (eXtreme Gradient Boosting) com poucas features.
- **Regressão isotônica / monótona** de gauge para tempo restante, por
  unidade.
- **Análise de sobrevivência** (Kaplan-Meier ou Cox) para “tempo até esvaziar”
  com intervalo de confiança. Exige vários ciclos completos de descarga.
- **Detecção de mudança** na sequência de gauge para estimar a taxa atual.
- **Fusão por Kalman** se o BLE (Bluetooth Low Energy) algum dia entregar
  porcentagem: gauge (lento e grosseiro) + BLE (rápido e ruidoso) → estimativa
  melhor que qualquer um sozinho.

#### Presets e automação (Q1, Q2)

- **Presets aprendidos por agrupamento:** normalizar os ajustes em um vetor,
  rodar k-means (k-médias) ou agrupamento hierárquico sobre o histórico de
  configurações. Os centróides viram “seus 3 modos de uso”. Zero rótulos,
  resultado explicável. Maior valor e menor risco da lista.
- **Preferência por aplicativo com Beta-Bernoulli:** para cada par (aplicativo,
  ajuste), contar ativações e desativações. Com 3–5 observações já dá para
  sugerir com confiança declarada.
- **Bandit contextual com Thompson sampling (amostragem de Thompson):** decide
  *se* sugere um perfil ao entrar em um aplicativo. Recompensa: o usuário
  aceitou e não reverteu em 30 segundos.
- **Mineração de sequência** (tipo PrefixSpan): “depois de abrir o OBS (Open
  Broadcaster Software), você liga low cut (corte de graves) em 80% das
  vezes”.
- **Regra de ouro:** nada que altere o dispositivo automaticamente pode
  depender de modelo opaco. O usuário precisa entender por que o perfil foi
  aplicado.

#### Engenharia reversa do protocolo (R1, R2, R4, R5)

- **Triagem de bytes desconhecidos por MI (informação mútua):** para cada
  byte, calcular entropia e MI (informação mútua) com contexto conhecido: NC (cancelamento de ruído)
  ligado, carregando, stereo (estéreo), distância, aplicativo). Ordena
  candidatos a RSSI (indicador de intensidade do sinal recebido) e bateria.
- **ANOVA (análise de variância) por byte:** alinhar duas capturas
  (antes/depois de um evento) e calcular a variância explicada pelo evento em
  cada byte. Ótimo para descobrir mute (silenciamento).
- **Regressão isotônica byte → distância:** caminhar a distâncias conhecidas e
  testar monotonicidade. O byte com maior correlação de Spearman é o candidato
  a RSSI (indicador de intensidade do sinal recebido). Muito mais defensável que jogar 105 bytes no XGBoost (eXtreme Gradient Boosting) e olhar
  feature importance (importância de variável).
- **PCA (análise de componentes principais) e ICA (análise de componentes
  independentes)** sobre o vetor de status: revelam dimensões latentes.
- **Agrupamento dos frames (quadros) `5b 04`** com k-means (k-médias) ou
  DBSCAN (agrupamento espacial por densidade): se houver estrutura, os
  centróides mostram quais bytes variam com o link (enlace).
- **Diferença de sequência para mute:** capturar 10 segundos, apertar o botão
  físico, capturar mais 10, alinhar e ver qual byte muda. Primeiro descobrir o
  **estado**; depois procurar o comando de escrita.
- **Validação automatizada por áudio:** ao testar comandos candidatos, medir o
  RMS (valor eficaz) do áudio do receptor. Queda de mais de 20 dB (decibéis)
  em 300 ms (milissegundos) com recuperação ao reverter é evidência de mute.
  Transforma suposição em evidência, mantendo a disciplina da skill de
  descoberta: poucos candidatos, um por vez, reversão sempre.

#### Gravação e safety track (A3)

- **Correlação cruzada normalizada entre canal 0 e canal 1:** correlação acima
  de 0,99 com offset (deslocamento) de ganho constante de −6 ou −12 dB
  (decibéis) prova que o canal 2 é a safety track (faixa de segurança). Se for
  baixa, são microfones independentes.
- **Dominância por canal:** falar em um transmissor por vez e comparar energia
  por canal. Define o mapeamento transmissor → canal.
- **VAD (detecção de atividade de voz) + corte de silêncio** para dividir
  takes (tomadas).
- **Detecção de take** por energia e histerese.

#### Diagnóstico e saúde do USB (U3, R6)

- **Saúde do enlace:** p95 de latência de ACK (confirmação), jitter, taxa de
  CRC (verificação de redundância cíclica) inválido e lacunas de sequência. Um
  health score (pontuação de saúde) por sessão.
- **Detecção de estado fantasma:** o aplicativo aplicou otimisticamente e o
  status não reconciliou em N segundos.
- **Alerta de identidade:** serial ou firmware mudou para o mesmo modelo.
- **Detecção de flapping (oscilação):** NC (cancelamento de ruído), charging
  (carregando) ou auto-off (desligamento automático) alternando rápido indica
  mau contato ou bateria no limite.

### 10.4 Onde XGBoost (eXtreme Gradient Boosting) encaixa

| Tarefa | Rótulo | Dados necessários | Por que boosting | Alternativa mais simples |
|---|---|---|---|---|
| Alerta de perda de link | Timeout de ACK (confirmação) futuro | 20–40 sessões com caminhada | Lida com features heterogêneas e não linearidade | HMM (modelo oculto de Markov) + CUSUM (soma cumulativa) |
| Sugestão de ganho | Gain (ganho) escolhido pelo usuário | 100–300 decisões registradas | Regressão tabular pequena | Regressão isotônica |
| Byte candidato a RSSI (indicador de intensidade do sinal recebido) | Distância medida | 5–10 caminhadas | Ranking com restrição monotônica | Spearman + isotônica |
| Tempo restante de bateria | Queda de gauge (escala) | Vários ciclos | Captura interação de estados | Regressão linear por estado |
| Anomalia de telemetria | Sessões marcadas manualmente | Poucas dezenas | Robusto a outliers | z-score + CUSUM (soma cumulativa) |
| Perfil aprendido | Nenhum (não supervisionado) | Histórico de ajustes | **Não usar** | k-means (k-médias) ou hierárquico |

Regra prática: **se não for possível dizer de onde vem o rótulo, não usar
XGBoost (eXtreme Gradient Boosting)**. Sem rótulo, o resultado é uma curva
bonita e uma decisão errada.

### 10.5 Implantação sem dependências de terceiros

- **Treino offline** em Python com `scikit-learn`, `xgboost` e `coremltools`,
  em `tools/`, como já se faz com `pyusb`. O artefato publicado precisa ser
  gerado por script reproduzível, não um binário opaco commitado.
- **Inferência no aplicativo**, duas opções:
  1. **CoreML (Core Machine Learning):** framework do sistema, sem dependência
     externa.
  2. **Árvores escritas à mão em Swift:** exportar limiares e folhas para JSON
     (JavaScript Object Notation) e escrever o walker (percorredor) em ~40
     linhas. Para 20–100 árvores é instantâneo, testável e 100% auditável.
- **DSP (processamento digital de sinais)** com Accelerate/vDSP, também do
  sistema.
- **Modelos minúsculos:** nada acima de algumas centenas de KB (quilobytes)
  para um aplicativo de barra de menus.

### 10.6 O que não fazer

- Rede neural profunda ou LLM (modelo de linguagem de grande porte) no caminho
  de controle: dados insuficientes, sem explicabilidade, sem ganho sobre regra
  + árvore.
- Aplicar ganho automaticamente com modelo sem consentimento.
- Chamar estimativa de RSSI (indicador de intensidade do sinal recebido) ou de
  bateria de “medição”. Se for modelo, é inferência e precisa de incerteza.
- Treinar com áudio na nuvem ou commitar gravações.
- XGBoost (eXtreme Gradient Boosting) direto em 105 bytes crus com uma sessão:
  ele decora o ruído. Primeiro reduzir dimensionalidade com MI (informação
  mútua) e monotonicidade.
- Mute (silenciamento) por proxy de ganho: abaixar o gain (ganho) ao mínimo não
  é mute e altera a configuração do usuário.

### 10.7 Avaliação

- Sempre **leave-one-session-out (deixa-uma-sessão-fora)**. Com um kit,
  validação aleatória é ilusão.
- Métricas: PR-AUC (área sob a curva precisão-revocação) para alerta de link,
  MAE (erro absoluto médio) em dB (decibéis) para ganho e calibração
  (o modelo diz 80%, acerta 80%?).
- Baseline obrigatório: regra simples ou estatística. Se o modelo não superar
  o baseline, não entra.
- Versionar o script de treino, o esquema dos dados e os hiperparâmetros
  (configurações de treino). Nunca versionar áudio ou serial.

---

## 11. Validações de hardware pendentes

Antes de estimar ou implementar os itens dependentes:

| Validação | Decide | Como |
|---|---|---|
| `0x000A` por unidade (`0x0001`/`0x0002`) | Q4 por TX (transmissor) | Enviar e observar LED (diodo emissor de luz) e status |
| Mapeamento de canais em mono + safety | A3 | Correlação cruzada entre canais |
| Faixa e passo reais de gain | A4 | Enviar valores e observar ACK (confirmação) + status |
| Frames `5b 04` | R2 | Capturar e agrupar |
| Coexistência de áudio e interface 6 | A1–A3 | Abrir as duas e medir |
| Gauge (escala) completo da bateria | R3, previsão | Descarga até o fim |
| Bit de charging (carregando) | Q3, previsão | Carregar e observar |
| Suporte a dois transmissores | Q1, Q4 | Kit com dois TX (transmissores) |
| BLE (Bluetooth Low Energy) no transmissor | R3 | Escanear com o kit ligado |
| Gravação interna no Mini 2 | R4 | Manual e identidade |

---

## 12. Roteiro revisado

### Fase 0 — Habilitadores (≈1 semana)

1. Persistência, `MicProfile` e `ProfileStore`.
2. `AppServices`, `AppDelegate` e dono único da sessão USB (Universal Serial Bus).
3. Assinatura estável.
4. CI (integração contínua).
5. `sendRaw` (envio cru) e redação de serial.
6. Núcleo do Protocol Lab (laboratório de protocolo).

O Protocol Lab sobe para cá porque é o que torna R1, R2, R4 e R5 pesquisáveis.

### Fase 1 — Produto (≈1,5 semana)

1. Q1 (presets) e Q6 (backup), na mesma base.
2. Q2 (perfil por aplicativo).
3. Q3 (notificações).
4. Q5 (iniciar ao fazer login), após P4.
5. Q4 (encontrar transmissor), após validação.
6. Q9 (barra de menus compacta).
7. Q8 (atalhos).

### Fase 2 — Áudio (≈3 semanas)

1. Módulo `DJIMicAudio` e validação do mapeamento de canais.
2. A1 (medidor).
3. A5 (entrada padrão).
4. Q7 (sound check).
5. A4 (auto-gain), só no modo “Suggest” (sugerir).
6. A2 (monitoramento).
7. A3 (gravação com safety track).

### Fase 3 — Integrações e distribuição (≈2 semanas)

1. P4 (notarização).
2. P2 (esquema de URL e interface de linha de comando).
3. Migração para Xcode, se P1 e P3 forem mantidos.
4. P1 (App Intents).
5. P5 (atualização automática).
6. P7 (idiomas).
7. U1 a U5.
8. P6 (integração contínua) já na Fase 0; aqui só o endurecimento.

### Fase 4 — Pesquisa

1. R2 (`5b 04` primeiro).
2. R1 (só com captura externa).
3. R5 (pareamento).
4. R3 e R4 (checagens de 30 minutos para decidir se morrem).
5. P3 (central de controle).

### Fase 5 — Dados e modelos (contínua, após Fase 0)

1. `TelemetryRecorder` (gravador de telemetria).
2. Features de DSP (processamento digital de sinais) e dashboards
   (painéis).
3. Regras estatísticas: CUSUM (soma cumulativa), EWMA (média móvel ponderada
   exponencialmente), isotônica.
4. Validação por áudio da safety track (faixa de segurança) e de candidatos a
   mute (silenciamento).
5. Engenharia reversa não supervisionada: MI (informação mútua), PCA (análise
   de componentes principais), agrupamento.
6. Presets aprendidos por agrupamento.
7. XGBoost (eXtreme Gradient Boosting) só com 20+ sessões rotuladas.

Estimativa total: **7–8 semanas** de trabalho focado, sendo ~2 semanas de
pesquisa sem garantia de resultado, mais a fase de dados em paralelo.

---

## 13. Critérios gerais de aceite

- Nenhuma funcionalidade pode bloquear a UI (interface do usuário) durante I/O (entrada e saída)
  USB (Universal Serial Bus).
- Todo comando precisa de ACK (confirmação) e tratamento de `0xff` (rejeição).
- O estado do dispositivo continua sendo a fonte da verdade.
- Aplicação de preset (predefinição) é sequencial, com progresso e cancelamento.
- Toda ação destrutiva ou irreversível precisa de confirmação.
- Toda nova string precisa existir em `en` (inglês) e `pt-BR` (português do
  Brasil).
- Toda nova view (tela) precisa funcionar em tema claro/escuro e com Reduce
  Motion (redução de movimento).
- Nenhuma dependência de terceiros no aplicativo.
- Nenhum log (registro) exportável contém serial completo.
- Nenhum modelo de aprendizado de máquina altera o dispositivo sem opt-in.
- Toda inferência exibida como número precisa de incerteza ou de rótulo
  explícito de estimativa.
- Testes de lógica pura não dependem de hardware; transporte e áudio usam
  implementações falsas.
- O POC (proof of concept, prova de conceito) Python continua funcionando e não
  é dependência do aplicativo.

---

## 14. Glossário de siglas

| Sigla | Expansão |
|---|---|
| ACK | acknowledgement (confirmação) |
| API | Application Programming Interface (interface de programação de aplicações) |
| AUHAL | Audio Unit Hardware Abstraction Layer (camada de abstração de hardware de unidade de áudio) |
| BLE | Bluetooth Low Energy (Bluetooth de baixo consumo) |
| CAF | Core Audio Format (formato de áudio do Core Audio) |
| CI | continuous integration (integração contínua) |
| CLI | command-line interface (interface de linha de comando) |
| CoreML | Core Machine Learning (aprendizado de máquina da Apple) |
| CRC | cyclic redundancy check (verificação de redundância cíclica) |
| CUSUM | cumulative sum (soma cumulativa) |
| dB | decibel (decibel) |
| dBFS | decibels relative to full scale (decibéis relativos à escala máxima) |
| DBSCAN | Density-Based Spatial Clustering of Applications with Noise (agrupamento espacial por densidade) |
| DSP | digital signal processing (processamento digital de sinais) |
| DTO | data transfer object (objeto de transferência de dados) |
| DUML | DJI Universal Markup Language (linguagem de marcação universal da DJI) |
| EWMA | exponentially weighted moving average (média móvel ponderada exponencialmente) |
| FIR | finite impulse response (resposta ao impulso finita) |
| HAL | Hardware Abstraction Layer (camada de abstração de hardware) |
| HMM | hidden Markov model (modelo oculto de Markov) |
| Hz | hertz (hertz) |
| ICA | independent component analysis (análise de componentes independentes) |
| ID | identifier (identificador) |
| ITU | International Telecommunication Union (União Internacional de Telecomunicações) |
| JSON | JavaScript Object Notation (notação de objeto JavaScript) |
| JSONL | JSON Lines (linhas JSON) |
| kHz | kilohertz (quilohertz) |
| LED | light-emitting diode (diodo emissor de luz) |
| LLM | large language model (modelo de linguagem de grande porte) |
| LUFS | loudness units relative to full scale (unidades de sonoridade relativas à escala completa) |
| MAE | mean absolute error (erro absoluto médio) |
| MI | mutual information (informação mútua) |
| ML | machine learning (aprendizado de máquina) |
| ms | millisecond (milissegundo) |
| NC | noise cancellation (cancelamento de ruído) |
| PCA | principal component analysis (análise de componentes principais) |
| PI | proportional-integral (proporcional-integral) |
| POC | proof of concept (prova de conceito) |
| PR-AUC | precision-recall area under the curve (área sob a curva precisão-revocação) |
| RMS | root mean square (valor eficaz) |
| RSSI | received signal strength indicator (indicador de intensidade do sinal recebido) |
| RX | receiver (receptor) |
| SPM | Swift Package Manager (gerenciador de pacotes Swift) |
| TCC | Transparency, Consent, and Control (transparência, consentimento e controle) |
| TX | transmitter (transmissor) |
| UI | user interface (interface do usuário) |
| UID | unique identifier (identificador único) |
| USB | Universal Serial Bus (barramento serial universal) |
| UX | user experience (experiência do usuário) |
| VAD | voice activity detection (detecção de atividade de voz) |
| WAV | Waveform Audio File Format (formato de arquivo de áudio de forma de onda) |
| XGBoost | eXtreme Gradient Boosting (reforço de gradiente extremo) |
| ZCR | zero crossing rate (taxa de cruzamento por zero) |
