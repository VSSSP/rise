# Rise

Lembrete para levantar da cadeira e fazer uma série: a cada 45 minutos, só no horário comercial, o Rise pede
para você levantar, fazer as flexões e os abdominais, e guarda tudo num histórico com gráficos.

## Instalar

1. Abra `Rise-1.1.0.dmg` e arraste o **Rise** para **Aplicativos**.
2. Abra o Rise. Ele não aparece no Dock: o ícone do bonequinho fica na barra de menus, lá em cima, ao lado do
   relógio. Na primeira vez a janela abre sozinha para mostrar onde ele está.

O app é assinado só nesta máquina. Se o dmg vier da internet para outro Mac, abra o Rise com clique direito ›
**Abrir** na primeira vez.

## Como funciona

- Padrão: de segunda a sexta, das 9h às 18h, um aviso a cada 45 minutos.
- No aviso aparece um cartão no canto de cima da tela, por cima de tudo, e ele só sai quando você responde. Em
  cada linha (**Levantei**, **Flexões**, **Abdominais**) você marca **Fiz** ou **Não fiz**, e dá para ajustar o
  número antes. **Fiz tudo** grava tudo de uma vez, **Não fiz nada** grava que não fez, e **Adiar 5 min**
  traz o mesmo aviso de volta depois. Se chegar um aviso novo sem resposta no anterior, o anterior fica como
  "sem resposta".
- O cartão não rouba o foco: dá para continuar digitando onde estava.
- No ícone da barra: o próximo aviso, o resumo de hoje, **Registrar agora** (para uma série fora do aviso),
  **Pular o próximo aviso**, **Pausar hoje**, **Testar aviso**, **Abrir o Rise** e **Sair**.
- Na janela: **Hoje** (próximo aviso, o total do dia e os avisos de hoje), **Histórico** (gráficos de 7 e 30
  dias e a lista de registros; clique com o botão direito para apagar um registro errado) e **Ajustes**
  (horário, dias, quantas flexões e abdominais por aviso, som e abrir com a sessão).
- O histórico fica em `~/Library/Application Support/Rise/history.json`.
- Se o Mac estava dormindo na hora de um aviso, ele não toca atrasado.

## Gerar o dmg

Precisa das ferramentas de linha de comando do Xcode (`xcode-select --install`).

```sh
scripts/build.sh   # roda os testes e cria dist/Rise-<versão>.dmg
swift test         # só os testes do planejador e do histórico
```
