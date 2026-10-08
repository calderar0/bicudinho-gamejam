# Plano GameRex 2026: bicudinho e vidro

Versão do plano focada no desenvolvimento. O plano completo (cronograma hora a hora e tabelas de arte com todos os tamanhos) está no documento compartilhado do time.

## Resumo

Jogo de plataforma 2D em pixel art. O bicudinho-do-brejo-paulista, uma ave ameaçada que não enxerga o vidro, cruza fases ao longo do Tietê procurando uma fêmea. O jogador dobra as regras: estica, encolhe e corta a janela do jogo, arrasta ícones que viram plataformas e abre mini-janelas com dicas. Feito em Godot, exporta para web (HTML5) e Windows (.exe). Prazo: 23h, com 4 fases.

Texto de conservação do bicudinho: confirmar os fatos em fontes (por exemplo, SAVE Brasil) antes de publicar qualquer coisa no jogo ou no itch.io.

## Equipe

- Programador: código, builds web e exe.
- Artista 1: pixel art (bicudinho, cenário, desktop, ícones, UI).
- Artista 2: arte, game design (fases, textos) e SFX/música.

## Mecânica

- Plataforma 2D de tela única. O mundo da fase fica em coordenadas do desktop falso e a janela do jogo funciona como máscara: só existe o que está dentro dela.
- O bicudinho anda e pula (saltos curtos e rápidos). No ar, prepara o voo e dispara em linha reta, mirando com as setas, até bater em chão ou parede.
- Vidro: as bordas da janela. Andar contra elas só bloqueia, bater nelas durante a disparada atordoa, e se a borda se move contra o bicudinho, empurra (reinicia a fase se não houver espaço).
- Ícones arrastáveis viram plataformas e paredes (1 tile cada). O ícone `icon_brejo` é a saída da fase.
- Mini-janelas (bloco de notas e visualizador de imagem) trazem dicas e o tutorial, e são interface: não seguem a regra de ouro.
- O inimigo é só o ambiente: água suja do rio, lixo e vidros.

## Decisões fixadas

1. Godot 4.3+ com GDScript, export web sem threads.
2. Fases de tela única (rolagem de câmera fica de fora).
3. O saltitar do bicudinho é só animação. A disparada é mirada com as setas.
4. Disparada contra o vidro atordoa. Andar contra o vidro só bloqueia.
5. A janela empurra o bicudinho ao encolher, e reinicia a fase se ele for esmagado.
6. Pixel art: 640x360 ampliado 2x sem suavização, tiles e sprites em 16x16.
7. Movimento: pulo de 4 tiles de altura e 7 de distância, disparada de 5 tiles.

## Fora do escopo

Mexer em janelas ou ícones reais do sistema, rolagem de câmera, inimigos que andam, power-ups, moedas, chefes, arrastar a janela pela barra de título (só se sobrar tempo), terminal e outros tipos de mini-janela, salvar progresso, vários idiomas, cutscenes, mais de 5 fases.

## Fases

| Fase | Cenário | Ensina | Setup | Solução esperada |
| --- | --- | --- | --- | --- |
| 1. Brejo | Brejo limpo | Andar, pular, preparar voo e disparar, e o vidro | Janela fixa, plataformas simples e um poço de água suja | Chegar ao brejo e descobrir que a disparada contra o vidro atordoa |
| 2. Arrasta | Brejo com lixo | Ícones como plataforma | Buraco no chão e pastas soltas fora da janela | Arrastar as pastas para dentro da janela e formar uma ponte |
| 3. Estica | Margem urbana | Redimensionar | A saída está fora da janela inicial, então não existe | Esticar a janela para revelar o chão e a saída |
| 4. Corta | Rio na cidade | Encolher para cortar | O chão inteiro é rio poluído, com poucas plataformas altas | Encolher a janela pela base: o rio fica de fora e o vidro vira o chão |

Fase extra (só se sobrar tempo): 5. Tudo junto, com o vidro empurrando o bicudinho por cima de um vão, esticar para revelar a saída e um ícone arrastado como último degrau.

Mini-janelas por fase: fase 1, visualizador abre sozinho com os controles e o objetivo (achar a fêmea). Fase 2, bloco de notas com a pista de qual pasta arrastar. Fase 3, imagem com uma seta para a saída. Fase 4, bloco de notas com dica sobre encolher a janela e uma linha dizendo que o canto da fêmea está perto.

Regras de design: 1 ideia nova por fase; respeitar o movimento (4 tiles de altura, 7 de distância, disparada de 5, sempre com 1 tile de folga); a saída é sempre encontrável (uma dica mostra onde está se ela estiver fora da janela); margem de erro de pelo menos 15 px no jogo; tutorial por imagem e texto curto; todo mundo joga todas as fases 3 vezes antes de congelar.

Dados de cada fase (nó da cena): `window_x`, `window_y`, `window_w`, `window_h`, `min_w`, `min_h`, `max_w`, `max_h`, `bird_x`, `bird_y`, `exit_x`, `exit_y`, lista de ícones (`type`, `x`, `y`, `draggable`), `notepad_text`, `viewer_image`.

## Tarefas de programação

1. Base: projeto Godot 4.3+, 640x360 com escala inteira e filtro nearest, presets de export web e Windows na H1 e build de teste na H3, tela cheia (F), autoloads de estado e áudio, física em `_physics_process`.
2. Bicudinho: CharacterBody2D, andar, pulo de altura variável, coyote time e buffer (0,1 s), preparar voo (~0,15 s) com mira em 8 direções, disparada de até 5 tiles (uma por pulo), atordoamento de 0,5 s no vidro, colisão de ~12x14 px, animações e morte com reinício em menos de 1,5 s.
3. Desktop e janela: fundo e barra de tarefas, cursor customizado, janela com barra de título e canto de redimensionar, redimensionar pelas bordas com mínimo e máximo por fase, máscara (só o que está dentro desenha e colide), vidro sólido que empurra, esmagado reinicia, limite de velocidade do redimensionamento, variável única da regra do vidro.
4. Ícones: sprite e colisão, arrastar com grade de 16 px, só aparecem e colidem dentro da janela, tipos (fixo, arrastável, some se cortado, brejo, abre mini-janela).
5. Mini-janelas: componente único (moldura, título, fechar, arrastável), duplo clique abre, bloco de notas e visualizador lendo o nó de dados da fase, Esc ou botão fecha, `icon_help` reabre o tutorial.
6. Fases: cena com TileMap e nó de dados, carregador por cena, saída que vence a fase, tentativas, transições, atalho de debug para pular fase.
7. Telas: menu (Jogar, Créditos), pausa (Esc), vitória (o encontro com a fêmea, créditos e link da jam), mutar (M), tutorial na fase 1.
8. Juice: tremor de tela na batida, partículas de penas, cacos e respingos, rastro curto, transições com fade.
9. Áudio: gerenciador com pré-carregamento, música em loop baixa, som de cada evento, áudio só começa após o primeiro clique.
10. Build: export web (4.3+, sem threads, `index.html` na raiz do zip), export Windows (`.exe` e `.pck`, ou PCK embutido), testes em Chrome, Firefox e em outro computador, assets leves, sem erros no console.

## Nomes de arquivos de arte (PNG, 16x16 salvo indicação)

- Bicudinho: `bicudinho_idle` (2 frames), `bicudinho_walk` (4), `bicudinho_jump`, `bicudinho_prepare`, `bicudinho_dash`, `bicudinho_fall` (1 cada), `bicudinho_stun` (2), `bicudinho_dead` (1), `bicudinho_happy` (2), `female_idle` (2).
- Cenário: `tileset_ground_brejo`, `tileset_ground_city`, `tileset_platform`, `tile_river` (4 frames), `tile_trash` (3 variações).
- Efeitos: `fx_splash`, `fx_jump_dust`, `fx_feather`, `fx_dust`, `fx_star_stun`, `fx_exit_glow`, `glass_crack`, `glass_shards`.
- Ícones: `icon_folder`, `icon_file`, `icon_image`, `icon_app`, `icon_virus_fake`, `icon_brejo`, `icon_notepad`, `icon_viewer`, `icon_help`, `icon_drag_shadow`.
- Desktop e janela: `wallpaper_01` a `wallpaper_04`, `taskbar`, `cursor_arrow`, `cursor_hand`, `cursor_grab`, `cursor_resize_h`, `_v`, `_diag1`, `_diag2`, `window_titlebar`, `window_border`, `window_buttons`, `window_corner_handle`.
- Mini-janelas: `minwin_frame`, `minwin_close`, `notepad_page`, `font_pixel`, `tutorial_1` a `tutorial_4`.
- UI: `logo_title`, `btn_play`, `btn_credits`, `btn_back`, `screen_victory`, `screen_pause`, `ui_attempts`, `ui_level_indicator`.

## Nomes de sons (.ogg, mono, curtos; música em loop)

- Movimento: `sfx_jump`, `sfx_land`, `sfx_step_a`, `sfx_step_b`, `sfx_prepare`, `sfx_dash`, `sfx_flap` (toca na preparação do voo).
- Vidro e morte: `sfx_glass_hit`, `sfx_glass_crack`, `sfx_stun`, `sfx_bird_hurt`, `sfx_splash`, `sfx_trash_death`, `sfx_crush`.
- Janela e ícones: `sfx_window_drag`, `sfx_window_resize`, `sfx_window_limit`, `sfx_icon_pick`, `sfx_icon_drop`, `sfx_icon_blocked`, `sfx_icon_note`, `sfx_icon_vanish`, `sfx_window_open`, `sfx_window_close`.
- Progresso e UI: `sfx_exit_open`, `sfx_win_level`, `sfx_win_game`, `sfx_female_call`, `sfx_bird_chirp`, `sfx_ui_hover`, `sfx_ui_click`, `sfx_pause`, `sfx_transition`.
- Música: `music_menu`, `music_game`. Opcionais: `amb_brejo`, `amb_cidade`, `sfx_desktop_boot`.
- Regras: nenhum som acima de 1 MB, música abaixo de 2 MB, música a 30% do volume dos efeitos, mutar funciona desde o menu, licença e autor de cada arquivo anotados.

## Entrega no itch.io

- Zip web (HTML5, "played in the browser", embed 1280x720 com tela cheia) como versão principal, e zip Windows (`.exe`) só se testado em outro computador.
- Página: título, descrições (inglês, com português se couber), instruções de controle (setas ou A e D para andar, espaço para pular, espaço de novo no ar para preparar o voo, setas para mirar, mouse para arrastar ícones e bordas), tags, capa 630x500, screenshots, créditos com todo material de terceiros e marcação "AI-generated" onde houver IA.
- Regras da jam: sem conteúdo ofensivo, só teclado e mouse, sem downloads extras nem software externo, respeitar o tema, enviar **1 hora antes** do prazo (atraso desclassifica).
- Teste final: link público em janela anônima, jogar do menu à vitória, Chrome e Firefox, e uma pessoa de fora do time jogando sem explicação.

## Plano B (corte nesta ordem; o topo sai primeiro)

1. Fase extra 5 e efeitos opcionais
2. Tremor de tela e partículas de caco
3. Sons de ambiente e música do menu
4. Cursor customizado
5. Papéis de parede diferentes por fase
6. Imagens de dica das fases 3 e 4
7. Pausa de preparação do voo (a disparada sai direto)
8. Mira da disparada (vai só na direção do olhar)
9. Arrastar a janela pela barra de título
10. Bloco de notas (ficar só com o visualizador)
11. Fase 4 (reduzir a 3 fases bem feitas)
12. Build .exe (o web é a entrega principal)
13. **Nunca cortar:** andar e pular bem, a disparada (mesmo sem mira), janela redimensionável, ícones arrastáveis, vidro, tela de vitória, página do itch.io e envio no prazo.

Sinais de alerta: H6 sem janela redimensionável, o programador pede ajuda e o Artista 2 corta uma fase do design. H8 sem disparada jogável, cortar a mira e a pausa de preparação. H12 sem 3 fases jogáveis, congelar ideias e só polir. H17 sem export web testado, parar tudo e resolver o export. H21 sem build estável, só corrigir bugs.
