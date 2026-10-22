# Convenções de UI

## Layout

- painel: 380 × 540 pt
- header: 64 pt
- footer: 40 pt
- content inset: 16 pt
- cards: raio 10 pt
- spacing: 4, 8, 12, 16, 20, 24

## Estrutura

1. Header: modelo, firmware, status, bateria.
2. Receiver:
   - NC read-only com cadeado
   - gain (segmented)
   - monitoring (slider)
   - mono/stereo
   - safety
3. Transmitter:
   - voice tone
   - level
   - battery
   - link “More”
4. More Settings:
   - Audio Settings: Low Cut, Clipping
   - Buttons & LED: Mic LED
   - General: Auto Off
5. Footer: Diagnostics, Quit.

## Controles

- booleanos: `Toggle` + `.toggleStyle(.switch)`
- 3–5 opções: `Picker` + `.pickerStyle(.segmented)`
- valores contínuos: `Slider`
- labels: `SettingRow`
- seções: `SettingsSection`
- numéricos: `monospacedDigit`
- labels longos: `lineLimit(1)` + `minimumScaleFactor(0.85)`

## Cores e materiais

- sistema, SF Symbols
- `.regularMaterial` no painel/footer
- cards `.quaternary.opacity(0.28)`
- sem cores hex
- status: verde/laranja/cinza/vermelho + texto

## Movimento

- transição de página: 0.28 s, slide + fade
- medidor: 0.12 s
- erro: 0.2 s
- Reduce Motion: sem slide/animação do medidor
- não animar layout a cada status

## Acessibilidade

- VoiceOver em todos os controles
- `accessibilityLabel`/`accessibilityValue`
- não depender só de cor
- foco e teclado
- contraste em light/dark

## i18n

- `en` e `pt-BR`
- nenhuma string hardcoded
- testar largura em pt-BR
- logs técnicos podem ficar em inglês
