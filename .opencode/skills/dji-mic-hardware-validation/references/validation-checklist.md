# Checklist de validação

## Antes

- [ ] app fechado (se usar POC Python)
- [ ] RX conectado direto no Mac
- [ ] TX ligado e linkado
- [ ] `scan` encontra `0x2ca3:0x4011`
- [ ] baseline `status --raw` salvo
- [ ] valor atual de cada ajuste anotado
- [ ] comando/target/valor definidos
- [ ] plano de reversão definido

## Durante

- [ ] enviar apenas um comando
- [ ] ACK `0x00`
- [ ] aguardar próximo status
- [ ] campo esperado mudou
- [ ] efeito físico confirmado
- [ ] nenhum outro ajuste mudou sozinho
- [ ] sem timeout/erro USB

## Depois

- [ ] reverter ao valor original
- [ ] ACK `0x00` na reversão
- [ ] status voltou
- [ ] efeito físico voltou
- [ ] registrar resultado
- [ ] atualizar matriz/docs
- [ ] fechar POC antes de abrir o app

## Se falhar

- ACK `0xff`: pare; comando não suportado ou target/valor errado.
- Sem ACK: verifique sequência, timeout e concorrência.
- ACK ok mas status não muda: pode ser read-only, target errado ou campo
  diferente.
- Status muda mas efeito físico não: confira se o ajuste é realmente aplicável.
- Dispositivo estranho: remova e reconecte o USB; não envie mais comandos.
