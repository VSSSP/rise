# Rise

Lembrete para levantar da cadeira: o Mac avisa a cada 45 minutos, só no horário comercial.

## Instalar

1. Abra `Rise-1.0.0.dmg` e arraste o **Rise** para **Aplicativos**.
2. Abra o Rise. Na primeira vez, permita as notificações.
3. Dica: em **Ajustes do Sistema › Notificações › Rise**, escolha o estilo **Alertas**. Assim o aviso fica na
   tela até você responder, com os botões **Levantei** e **Adiar 5 min**.

O app é assinado só nesta máquina. Se o dmg vier da internet para outro Mac, abra o Rise com clique direito ›
**Abrir** na primeira vez.

## Como funciona

- Padrão: de segunda a sexta, das 9h às 18h. O primeiro aviso é às 9h45, e depois vem um a cada 45 minutos
  (o último às 18h).
- O ícone fica no Dock. Com o botão direito nele você tem **Levantei**, **Pular o próximo**, **Pausar hoje**
  e **Testar aviso**.
- Na janela você vê o próximo aviso e os horários de hoje (toque num horário para pular ou voltar a tocar), e
  muda o início, o fim, o intervalo, os dias e o som.
- O Rise abre sozinho quando você inicia a sessão. Dá para desligar isso na janela.
- Se o Mac estava dormindo na hora de um aviso, ele não toca atrasado.
- Com o Foco ou o Não Perturbe ligado, o macOS segura a notificação. Dá para liberar o Rise no Foco.

## Gerar o dmg

Precisa das ferramentas de linha de comando do Xcode (`xcode-select --install`).

```sh
scripts/build.sh   # roda os testes e cria build/Rise.app e dist/Rise-<versão>.dmg
swift test         # só os testes do planejador de avisos
```
