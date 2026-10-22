# Ideias de funcionalidades — DJI Mic Control

Backlog de evolução do app de barra de menus, organizado por valor, esforço e
dependência técnica.

Documentos relacionados:

- [`swift-app.md`](swift-app.md) — arquitetura e build do app atual
- [`protocol-notes.md`](protocol-notes.md) — protocolo USB já validado
- [`feature-matrix.md`](feature-matrix.md) — o que já funciona no hardware

## Contexto e restrições

O app já controla o receptor e o transmissor via USB bulk (interface 6) e lê
identidade, status, bateria e nível. Algumas ideias dependem de recursos que
ainda não foram descobertos no protocolo.

Restrições atuais:

- **Noise Reduction é read-only** no Mic Mini 2; o estado vem da chave física
  O/L/H do receptor.
- **Bateria do TX é um gauge de 7 níveis**, não porcentagem.
- A interface 6 fica em uso exclusivo enquanto o app está aberto.
- O app é distribuído fora da App Store; sandbox não é compatível com o acesso
  USB atual.
- Sem dependências de terceiros. Tudo que for usado deve ser implementado no
  projeto.

## Matriz de prioridade

| ID | Funcionalidade | Valor | Esforço | Dependência | Prioridade |
|---|---|---|---|---|---|
| Q1 | Presets de configuração | Alto | Baixo | Nenhuma | P0 |
| Q2 | Perfil automático por aplicativo | Alto | Baixo | `NSWorkspace` | P0 |
| Q3 | Notificações de estado | Alto | Baixo | `UserNotifications` | P0 |
| Q4 | Find my TX (piscar LED) | Médio | Baixo | Comando `0x0A` | P1 |
| Q5 | Launch at login | Médio | Baixo | `SMAppService` | P1 |
| Q6 | Backup/restore de settings | Médio | Baixo | Estado atual | P1 |
| Q7 | Sound check | Alto | Médio | CoreAudio + permissão | P1 |
| Q8 | Atalhos de teclado | Médio | Médio | Carbon/`NSEvent` | P2 |
| Q9 | Menu bar compacto | Médio | Baixo | `MenuBarExtra` | P2 |
| A1 | Medidor profissional | Alto | Médio | CoreAudio | P1 |
| A2 | Monitoramento de áudio | Médio | Médio | CoreAudio | P2 |
| A3 | Gravação com safety track | Alto | Alto | CoreAudio + disco | P2 |
| A4 | Auto-gain assistido | Alto | Médio | CoreAudio + comandos | P2 |
| A5 | Troca automática de input padrão | Médio | Médio | CoreAudio | P2 |
| R1 | Mute do TX | Muito alto | Alto | RE do protocolo | P2 |
| R2 | Qualidade do link / RSSI | Alto | Alto | RE do status | P3 |
| R3 | Bateria em % via BLE | Médio | Alto | CoreBluetooth + RE | P3 |
| R4 | Internal recording / 32-bit float | Médio | Alto | Hardware 2S + RE | P3 |
| R5 | Pairing / linking | Médio | Alto | RE do protocolo | P3 |
| R6 | Protocol Lab | Alto | Médio | Base de diagnóstico | P1 |
| P1 | App Intents / Shortcuts | Alto | Médio | `AppIntents` | P1 |
| P2 | URL scheme / CLI | Médio | Baixo | Sessão atual | P2 |
| P3 | Control Center widget | Médio | Alto | APIs recentes | P4 |
| P4 | Notarização e assinatura | Alto | Médio | Developer ID | P1 |
| P5 | Atualização automática | Médio | Médio | Release próprio | P3 |
| P6 | CI macOS + testes | Alto | Baixo | GitHub Actions | P1 |
| P7 | Mais idiomas | Médio | Baixo | Strings atuais | P3 |

Prioridades:

- **P0** — próximo ciclo.
- **P1** — alto retorno, risco controlado.
- **P2** — diferencial, exige áudio ou RE.
- **P3** — pesquisa/investigação.
- **P4** — depende de APIs ou produto mais maduro.

---

## 1. Quick wins

### Q1 — Presets de configuração

**Descrição:** presets como *Interview*, *Outdoor*, *Podcast* e *Music* que
aplicam um conjunto de ajustes com um clique.

**O que entra em um preset:**

- gain e monitoring gain
- voice tone
- low cut
- mic LED
- auto-off
- clipping control
- mono/stereo
- safety track

**Implementação:**

- Modelo `MicProfile` `Codable` com nome, ícone SF Symbol e lista de
  `MicSetting`.
- Aplicação sequencial com ACK por comando; mostrar progresso.
- Salvar em `Application Support/com.niko.djimic/profiles.json`.
- Importar/exportar JSON.
- Preset “Current settings” para criar a partir do estado atual.
- Não incluir NC no preset (é físico/read-only).

**Cuidados:**

- Aplicar um preset não deve sobrescrever um ajuste que o usuário acabou de
  mudar manualmente sem confirmação.
- Se um comando for rejeitado, parar e mostrar qual falhou.

### Q2 — Perfil automático por aplicativo

**Descrição:** aplicar um preset quando um app específico estiver em primeiro
plano.

Exemplos:

- Zoom/Meet/Teams → *Interview*
- OBS/Streamlabs → *Streaming*
- QuickTime/Final Cut → *Recording*
- Voice Memos → *Podcast*

**Implementação:**

- `NSWorkspace.shared.notificationCenter` com
  `didActivateApplicationNotification`.
- Mapear bundle ID → profile ID.
- Debounce de 300–500 ms para não aplicar durante alternância rápida.
- Opção global “Automation” desligada por padrão.
- Mostrar no painel qual perfil foi aplicado automaticamente.

**Cuidados:**

- Não aplicar perfil se o usuário estiver com o painel aberto.
- Registrar os últimos eventos no diagnostics.

### Q3 — Notificações de estado

**Descrição:** avisar sobre eventos importantes sem abrir o app.

Eventos:

- bateria baixa do TX (gauge ≥ 6)
- TX desconectado
- RX desconectado
- clipping detectado
- NC mudou pela chave física
- preset automático aplicado
- falha de comando USB

**Implementação:**

- `UNUserNotificationCenter`, permissão pedida no primeiro uso.
- Rate limit por evento (ex.: uma notificação de bateria a cada 10 min).
- Ações rápidas: “Abrir painel”, “Reconectar”.
- Preferência por tipo de notificação.

### Q4 — Find my TX

**Descrição:** piscar o LED do transmissor para identificar a unidade física.

**Implementação:**

- Enviar `0x0A` alternando `0` (on) e `2` (off) 3–4 vezes.
- Restaurar o estado anterior ao final, inclusive em cancelamento ou erro.
- Desabilitar o botão durante a animação.
- Com dois TXs, permitir escolher TX1 ou TX2 via target (`0x0001`/`0x0002`).
- Target por TX ainda não validado no hardware; só o broadcast foi.

**Cuidados:**

- Não usar se o TX estiver gravando ou com LEDs já desligados por opção do
  usuário; perguntar antes.

### Q5 — Launch at login

**Descrição:** iniciar o app junto com o macOS.

**Implementação:**

- `SMAppService.mainApp.register()` / `unregister()`.
- Toggle em preferências.
- Requer app bundle assinado e instalado em `/Applications`.
- Mostrar estado real do sistema, não apenas preferência local.

### Q6 — Backup/restore de settings

**Descrição:** exportar e restaurar todas as configurações do kit.

**Formato sugerido:**

```json
{
  "schema": 1,
  "createdAt": "2026-10-22T00:00:00Z",
  "receiver": {
    "gain": 0,
    "monitoringGain": 0,
    "stereo": false,
    "safetyTrack": false,
    "clippingControl": true,
    "autoOff": true
  },
  "transmitters": {
    "1": {
      "voiceTone": "bright",
      "lowCut": true,
      "ledsOff": false,
      "autoOff": true
    }
  }
}
```

**Implementação:**

- Reutilizar `MicProfile`.
- Restore com confirmação e relatório de comandos aplicados/rejeitados.
- Ignorar NC.
- Nunca incluir serial completo em logs públicos.

### Q7 — Sound check

**Descrição:** medir o áudio por alguns segundos e sugerir ajustes.

**Implementação:**

- `AVAudioEngine` capturando a entrada USB do RX.
- Medir peak, RMS, dBFS e ruído de fundo por 10 s.
- Sugerir:
  - gain ideal
  - low cut on/off
  - posição do microfone
  - possível clipping
- Botão “Apply suggestion” para o usuário confirmar.
- Exigir `NSMicrophoneUsageDescription` e permissão.

**Cuidados:**

- Não ajustar automaticamente sem opt-in.
- Não prometer redução de ruído: NC é físico.

### Q8 — Atalhos de teclado

**Descrição:** atalhos locais e globais para ações frequentes.

Exemplos:

- abrir/fechar painel
- aplicar preset
- Find my TX
- mute (se o protocolo permitir)

**Implementação:**

- Atalhos locais via `Commands` / `keyboardShortcut`.
- Globais via Carbon `RegisterEventHotKey` ou `NSEvent` global monitor.
- Alguns atalhos globais exigem permissão de Acessibilidade.
- Preferências para gravar/alterar atalhos.

### Q9 — Menu bar compacto

**Descrição:** modo enxuto para quem não quer abrir o painel.

Opções:

- ícone de microfone + bateria baixa
- ponto de clipping
- mini medidor de 2–3 barras
- texto opcional “TX1”

**Implementação:**

- Label customizado no `MenuBarExtra`.
- Atualizar no máximo 5–10 Hz e só quando o valor mudar.
- Evitar animação contínua na barra de menus.
- Preferência “Compact menu bar”.

---

## 2. Áudio profissional

### A1 — Medidor profissional

**Descrição:** transformar o nível atual em um medidor confiável.

Recursos:

- dBFS
- peak hold
- clip count
- histórico de 30 s
- sparkline por TX
- indicador de “hot signal”

**Implementação:**

- `AVAudioEngine` + `installTap` no input do RX.
- Buffer circular de 30 s.
- Desenho com SwiftUI `Canvas` ou `Path`.
- Sem dependências externas.
- Taxa de atualização visual de 15–30 Hz.

### A2 — Monitoramento de áudio

**Descrição:** ouvir o microfone pelo Mac.

**Implementação:**

- Rotear input para output via `AVAudioEngine`.
- Aviso de feedback; recomendar fones.
- Controle de volume separado do monitoring gain do RX.
- Botão “Monitor” com estado claro.
- Detectar fones/dispositivo de saída.

**Cuidados:**

- Feedback acústico é sério; nunca ativar automaticamente.
- Não confundir com o monitoring gain do dispositivo.

### A3 — Gravação com safety track

**Descrição:** gravar o áudio do RX em arquivo, separando canal principal e
safety track.

**Implementação:**

- `AVAudioFile` em WAV/CAF.
- Nome automático: data + preset + take.
- Se safety track estiver ativo, gravar dois arquivos ou um arquivo com duas
  faixas.
- Peak/clip log por take.
- Indicador de espaço em disco.
- Permissão de microfone e acesso a arquivos.

**Cuidados:**

- Testar se o canal 2 realmente contém a safety track no modo Mono.
- Não apagar arquivos automaticamente.
- Evitar gravação em rede sem aviso.

### A4 — Auto-gain assistido

**Descrição:** manter o nível saudável sem o usuário ficar ajustando.

**Implementação:**

- Modo “Suggest” (só sugere) e “Auto” (aplica com opt-in).
- Histerese para evitar comandos em loop.
- Limite de uma alteração a cada 500 ms.
- Respeitar clipping control do dispositivo.
- Voltar ao ganho manual se o usuário mexer no slider.

**Cuidados:**

- Nunca aplicar ganho durante uma fala importante sem aviso.
- Registrar cada ajuste no diagnostics.

### A5 — Troca automática de input padrão

**Descrição:** ao conectar o RX, torná-lo entrada padrão; ao desconectar,
restaurar a entrada anterior.

**Implementação:**

- CoreAudio: `kAudioHardwarePropertyDefaultInputDevice`.
- Guardar o device ID anterior.
- Opção “Set as default input” no onboarding/preferências.
- Notificar quando a troca falhar.

**Cuidados:**

- Não alterar durante chamadas sem consentimento.
- Restaurar apenas se o dispositivo anterior ainda existir.

---

## 3. Engenharia reversa e recursos avançados

### R1 — Mute do TX

**Descrição:** botão de mute/unmute no painel e atalho global.

**Status:** comando ainda não descoberto.

**Abordagem:**

- Capturar tráfego do app oficial ao mutar pelo TX/app.
- Testar comandos candidatos com valores 0/1 e observar status.
- Validar com TX físico e LED/áudio.
- Não publicar até ter ACK e efeito confirmados.

**Potencial:** um dos recursos mais úteis para chamadas e streams.

### R2 — Qualidade do link / RSSI

**Descrição:** mostrar força do link e alertar sobre distância.

**Status:** há bytes desconhecidos no status.

**Abordagem:**

- Caminhar com o TX e capturar o status em distâncias conhecidas.
- Correlacionar bytes com perda de pacotes/nível.
- Se não houver RSSI, usar taxa de perda/telemetria como proxy.

### R3 — Bateria em porcentagem via BLE

**Descrição:** obter percentual real em vez do gauge de 7 níveis.

**Status:** o TX tem BLE direto com o celular; não investigado.

**Abordagem:**

- CoreBluetooth no Mac.
- Procurar Battery Service padrão (`0x180F` / `0x2A19`).
- Se não existir, mapear características proprietárias.
- Manter o gauge USB como fallback.

**Cuidados:**

- Permissão de Bluetooth.
- BLE e USB podem não coexistir em todos os modos.

### R4 — Internal recording / 32-bit float

**Descrição:** controlar gravação interna e formato de 32-bit float.

**Status:** recursos de DJI Mic Mini 2S; o Mini 2 pode não suportar.

**Abordagem:**

- Confirmar modelo e firmware.
- Testar comandos já mapeados em [`feature-matrix.md`](feature-matrix.md).
- Não expor na UI se o dispositivo não reportar suporte.

### R5 — Pairing / linking

**Descrição:** gerenciar pareamento e linking de TXs pelo app.

**Status:** comandos não explorados.

**Abordagem:**

- Capturar linking pelo app oficial.
- Mapear comandos e estados.
- Implementar só com confirmação e recovery claros.

### R6 — Protocol Lab

**Descrição:** ferramenta de inspeção e experimentação do protocolo.

Recursos:

- árvore decodificada por frame
- filtros por tipo/ID
- envio de pacote cru
- replay de captura
- latência de ACK
- export JSONL
- busca de comandos
- comparação de capturas

**Implementação:**

- Evoluir `DiagnosticsView`.
- `RawSend` protegido por modo desenvolvedor e confirmação.
- Reutilizar `DJIMicProtocol` e `MicSession`.
- Nunca permitir comandos destrutivos por engano.

---

## 4. Produto, integrações e distribuição

### P1 — App Intents / Shortcuts

Ações:

- “Apply Mic Profile”
- “Set Gain”
- “Find My Transmitter”
- “Show Mic Panel”
- “Mute” (quando disponível)

Implementação com `AppIntents`; bom para Stream Deck, Shortcuts e automações.

### P2 — URL scheme / CLI

- `djimic://preset/outdoor`
- `djimic://gain/6`
- CLI `djimic status`, `djimic preset outdoor`, `djimic monitor`.

Reutilizar `DJIMicSession`; argumentos sem dependências externas.

### P3 — Control Center widget

Avaliar `WidgetKit` / Control Center conforme a versão mínima do macOS.
Pode oferecer acesso rápido a preset, mute e nível.

### P4 — Notarização e assinatura

- Developer ID Application
- hardened runtime
- notarização
- instruções de instalação sem Gatekeeper

Sem sandbox por causa do acesso USB.

### P5 — Atualização automática

- JSON de release próprio.
- Download + verificação de assinatura.
- Sem Sparkle ou terceiros.
- Canal stable/beta.

### P6 — CI macOS

- `swift test` em GitHub Actions.
- Testes de protocolo e sessão.
- Snapshot tests de UI em light/dark/pt-BR.
- Build do `.app` e verificação do bundle.

### P7 — Mais idiomas

- es, fr, de, ja, zh.
- Manter paridade de chaves via teste.
- Revisar largura dos controles para alemão e japonês.

---

## 5. UX, acessibilidade e qualidade

### U1 — Onboarding

- Explicar que NC é chave física.
- Pedir permissão de microfone só quando o recurso de áudio for usado.
- Explicar por que o app ocupa a interface USB.
- Detectar dispositivo e mostrar “pronto”.

### U2 — Acessibilidade

- VoiceOver completo em todos os controles.
- Navegação por teclado.
- Alto contraste.
- Reduce Motion e Reduce Transparency.
- Não depender só de cor para status.

### U3 — Diagnóstico de erros

- Mensagens específicas por erro USB.
- Exportar log com versão do app, firmware, macOS.
- Botão “Copiar diagnóstico”.

### U4 — Estado vazio e reconexão

- Placeholder claro quando não há TX.
- Banner de reconexão sem bloquear o app.
- Última configuração conhecida esmaecida.

### U5 — Preferências

- launch at login
- notificações
- compact menu bar
- atalhos
- presets e automação
- idioma
- diagnóstico

---

## 6. Roadmap sugerido

### Fase 1 — Produto utilizável

1. Presets (Q1)
2. Perfil por app (Q2)
3. Notificações (Q3)
4. Launch at login (Q5)
5. Find my TX (Q4)
6. Backup/restore (Q6)

### Fase 2 — Áudio

1. Medidor profissional (A1)
2. Sound check (Q7)
3. Auto-gain assistido (A4)
4. Troca de input padrão (A5)
5. Gravação com safety track (A3)

### Fase 3 — Integrações

1. App Intents / Shortcuts (P1)
2. URL scheme / CLI (P2)
3. Protocol Lab (R6)
4. CI e notarização (P6, P4)

### Fase 4 — Pesquisa

1. Mute do TX (R1)
2. RSSI / link quality (R2)
3. Bateria via BLE (R3)
4. Internal recording (R4)
5. Pairing (R5)

---

## 7. Não fazer agora

- Atualização de firmware pelo app.
- Formatação de gravação interna.
- Escrita de Noise Reduction no Mic Mini 2.
- Comandos não documentados sem confirmação e recovery.
- Prometer porcentagem de bateria que o protocolo não fornece.
- Automação agressiva de ganho durante uso ao vivo.

## 8. Critérios gerais de aceite

- Nenhuma funcionalidade deve bloquear a UI durante I/O USB.
- Todo comando precisa de ACK e tratamento de `0xff`.
- O estado do dispositivo continua sendo a fonte da verdade.
- Toda ação destrutiva ou irreversível precisa de confirmação.
- Toda nova string precisa existir em `en` e `pt-BR`.
- Toda nova view precisa funcionar em light/dark e com Reduce Motion.
- Nenhuma dependência de terceiros.
