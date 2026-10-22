# Swift menu bar app

Branch: `feat/professional-ui` (a partir de `feat/swift-menu-bar-app`).

Aplicativo nativo de barra de menus para configurar o receptor DJI Mic Mini 2
pelo USB. Não usa código de terceiros; o único código externo é o POC Python,
que continua disponível em `tools/poc/` e não é usado pelo app.

## Módulos

```
DJIMicProtocol   DUML puro: CRC, framing, parser, modelos e comandos
DJIMicTransport  shim C/IOKit + wrapper Swift; só move bytes
DJIMicSession    fila de comandos, ACK, estado consolidado, reconexão
DJIMicUI         SwiftUI, design system, i18n e modelo de tela
DJIMicApp        composição, MenuBarExtra e janela de diagnóstico
```

Regras:

- `DJIMicProtocol` não importa IOKit nem SwiftUI.
- `DJIMicTransport` não conhece DUML.
- `DJIMicSession` depende de `USBTransporting` e `MicClient`, não de IOKit.
- `DJIMicUI` não acessa USB.
- `DJIMicApp` só compõe.

## Rodar

```bash
swift test
./Scripts/build-app.sh
open Release/DJIMic.app
```

O app tem bundle ID `com.niko.djimic`, `LSUIElement=1` (sem ícone no Dock) e
assinatura ad-hoc. O binário fica em `Release/DJIMic.app`.

## Comportamento

- Detecta `0x2ca3:0x4011`, interface 6, endpoints bulk `0x06`/`0x86`.
- Lê identidade, firmware, status, bateria e nível.
- Escreve gain, monitoring gain, safety track, mono/stereo, low cut, mic LED,
  voice tone, clipping e auto-off.
- NC é somente leitura: controlado pela chave física O/L/H do receptor.
- Bateria é mostrada em barras/estado; não há porcentagem no protocolo.
- Reconecta quando o cabo é removido e recolocado.
- Diagnóstico em janela separada, com exportação JSONL.

## i18n

- `en` e `pt-BR`, com fallback em inglês.
- Chaves em `Sources/DJIMicUI/Resources/*.lproj/Localizable.strings`.
- Nome do app localizado em `Packaging/*.lproj/InfoPlist.strings`.
- Teste de paridade de chaves em `Tests/DJIMicUITests`.

## Design e HIG

- Painel compacto de 380 × 540 pt, com header, conteúdo rolável e footer fixo.
- Seções em cards arredondados, com espaçamento consistente (4/8/12/16/20/24 pt).
- Tipografia do sistema, valores numéricos monoespaçados e labels com
  `minimumScaleFactor` para acomodar pt-BR.
- "More Settings" é uma página interna com transição curta, em vez de empurrar
  o conteúdo principal para baixo.
- O botão "More" fica no header da seção do transmissor, replicando o padrão
  do app oficial.
- Medidor de nível com gradiente e animação curta; bateria com troca de
  símbolo.
- Otimistic update: o controle responde imediatamente e o status do
  dispositivo reconcilia em seguida.
- O `MicSession` não publica snapshots idênticos, reduzindo re-renders e
  stutter.

## Acessibilidade

- VoiceOver labels/values nos controles principais.
- Reduce Motion desliga a transição de página e a animação do medidor.
- Tema claro/escuro automático e materiais do sistema.

## Pendências de validação visual

- Abrir o painel na barra de menus e conferir foco/teclado.
- Validar light/dark e Reduce Motion numa sessão real.
- Validar os dois transmissores, se disponíveis.
