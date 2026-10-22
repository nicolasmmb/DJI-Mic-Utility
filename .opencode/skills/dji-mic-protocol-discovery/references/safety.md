# Segurança na descoberta

## Proibido sem pesquisa

- firmware update
- factory reset
- formatação de storage interno
- comandos de bootloader
- reboot do RX sem necessidade
- fuzzing prolongado

## Antes de cada teste

- app fechado, se usar POC;
- baseline salvo;
- valor original anotado;
- plano de reversão;
- comando e target definidos;
- sabe o que observar.

## Durante

- um comando por vez;
- espere ACK;
- espere status;
- pare em caso de `0xFF`;
- pare em caso de timeout repetido;
- não envie o próximo comando sem confirmar o estado.

## Se o dispositivo parar

1. pare de enviar;
2. remova o USB;
3. aguarde 5 s;
4. reconecte;
5. rode `scan`/`status`;
6. se não voltar, teste o áudio em `system_profiler`;
7. não tente “consertar” com comandos desconhecidos.

## Dados

- não publique serial completo;
- não anexe captura com áudio;
- registre firmware e data;
- se compartilhar captura, remova dados pessoais.
