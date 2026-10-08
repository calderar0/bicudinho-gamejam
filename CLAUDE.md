# CLAUDE.md

Jogo de plataforma 2D em pixel art para a GameRex 2026 (game jam, ~23h). Leia `PLANO.md` para o plano completo (mecânica, fases, listas de arte e sons, plano B).

## Projeto

- O bicudinho-do-brejo-paulista anda e pula pelas fases e procura uma fêmea ao longo do Tietê, do brejo limpo até a cidade. O inimigo é só o ambiente (água suja, lixo, vidro).
- A tela é um desktop falso. Dentro dele há uma "janela do jogo" falsa que o jogador estica, encolhe e corta com o mouse. Ícones do desktop falso são arrastáveis e viram plataformas e paredes. Mini-janelas (bloco de notas e visualizador de imagem) trazem dicas.
- Nunca mexer em janelas, ícones ou arquivos reais do sistema. Tudo é simulado dentro do jogo.

## Stack e regras técnicas

- Godot 4.3 ou mais novo, em **GDScript** (C# não exporta para web no Godot 4; confirmar na versão do projeto).
- Exports: **web (HTML5, sem threads)** é a entrega principal; **Windows (.exe)** é secundária. Os presets de export existem desde o início, e todo trabalho novo deve funcionar nas duas.
- Resolução do jogo: **640x360**, ampliada em múltiplos inteiros (2x = 1280x720) ou tela cheia, com filtro de textura **nearest** (sem suavização). Tiles de **16x16**. Sprites do bicudinho, ícones, cursores e efeitos em 16x16.
- Física em `_physics_process`. Nenhum movimento pode depender do FPS.
- Todos os números de ajuste ficam num único autoload `tuning.gd` (constantes), para o time balancear sem caçar valores no código.
- Caminhos relativos e nomes de arquivo em minúsculas, sem espaços: `bicudinho_walk.png`, `icon_folder.png`, `sfx_glass_hit.ogg`.
- Estrutura: `art/`, `sfx/`, `music/`, `levels/`, `scenes/`, `scripts/`. Fases são cenas `levels/level_01.tscn`, `level_02.tscn`...

## Regras do jogo que o código precisa respeitar

1. **Regra de ouro:** tudo que está fora da janela do jogo não existe (não desenha, não colide, não machuca). Vale para tiles, espinhos, ícones e a saída. Ao entrar ou sair da janela, ligar e desligar as colisões.
2. **Vidro:** as bordas da janela são vidro sólido (4 corpos estáticos que seguem a janela). Andar contra ele só bloqueia. Bater nele durante a disparada atordoa (0,5 s) e interrompe o voo. Se a borda se move contra o bicudinho, empurra; se não há espaço, a fase reinicia. A regra do vidro fica numa variável única (`GLASS_RULE` no `tuning.gd`: bloquear, atordoar ou matar).
3. **Movimento do bicudinho** (CharacterBody2D): andar com aceleração e atrito, pulo curto e rápido com altura variável, coyote time 0,1 s, buffer de pulo 0,1 s. No ar, apertar pular de novo faz uma pausa de ~0,15 s (gravidade quase zerada) em que o jogador mira com as setas (8 direções), e depois uma disparada em linha reta e rápida até bater em chão ou parede. Só uma disparada por pulo. Valores de referência: pulo de 4 tiles de altura e 7 de distância, disparada de 5 tiles. Colisão de ~12x14 px.
4. **Ícones:** arrastáveis com o mouse (grade de 16 px), 1 tile cada. Só colidem e aparecem dentro da janela. Não podem ser largados sobre o bicudinho nem dentro de parede. Tipos: fixo, arrastável, some se cortado, brejo (saída da fase) e os que abrem mini-janelas.
5. **Mini-janelas:** componente único (moldura, barra de título, botão de fechar, arrastável, espaço para conteúdo). Ficam acima de tudo, não seguem a regra de ouro e nunca colidem com o bicudinho. Conteúdo vem do nó de dados da fase (`notepad_text`, `viewer_image`). A fase 1 abre o visualizador sozinho com o tutorial.
6. **Morte** (rio, lixo, queda ou esmagado): congela, anima e reinicia a fase em menos de 1,5 s.

## Dados de cada fase (nó na cena)

`window_x`, `window_y`, `window_w`, `window_h`, `min_w`, `min_h`, `max_w`, `max_h`, `bird_x`, `bird_y`, `exit_x`, `exit_y`, lista de ícones (`type`, `x`, `y`, `draggable`), `notepad_text`, `viewer_image`. As fases são montadas no editor de tilemap do Godot.

## Como trabalhar neste repositório

- Faça primeiro o que está no MVP do `PLANO.md`. Não adicione nada da lista "fora do escopo".
- Use placeholders (quadrados coloridos) enquanto a arte final não chega, trocando só o arquivo depois.
- Se algo atrasar, siga a ordem de cortes do plano B do `PLANO.md`. Nunca cortar: andar e pular bem, a disparada, a janela redimensionável, os ícones arrastáveis, o vidro, a tela de vitória e o envio no prazo.
- Qualquer som, fonte, imagem ou código de terceiros entra com licença e autor anotados em `CREDITS.md`. Qualquer coisa gerada por IA deve ser marcada como "AI-generated", como exige a regra da jam.
- Antes de commitar, rode o jogo no editor e confira o console sem erros. Faça um export web e um export Windows de teste nos marcos do plano (H3 e H17), nunca só no fim.
- Exemplos de comando de export (ajustem os nomes dos presets): `godot --headless --export-release "Web" build/web/index.html` e `godot --headless --export-release "Windows Desktop" build/win/jogo.exe`.
- O jogo precisa rodar só com teclado e mouse, sem downloads extras e sem software externo.
