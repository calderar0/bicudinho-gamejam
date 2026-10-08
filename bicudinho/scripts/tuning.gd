extends Node
## Todos os números de ajuste do jogo ficam aqui. Balanceie sem caçar valores no código.
## Referência: pulo de 4 tiles de altura e 7 de distância, disparada de 5 tiles.

const TILE := 16
const SCREEN_W := 640
const SCREEN_H := 360
const TASKBAR_H := 20.0

# --- Debug --------------------------------------------------------------------
## Imprime no console a altura e a distância de cada pulo. Desligue antes do export.
const DEBUG_MEASURE := true

# --- Bicudinho: andar e pular -------------------------------------------------
const RUN_SPEED := 150.0
const GROUND_ACCEL := 1100.0
const AIR_ACCEL := 700.0
const GROUND_FRICTION := 1300.0
const AIR_FRICTION := 250.0
const GRAVITY := 900.0
const JUMP_VELOCITY := -350.0   # altura = v^2 / 2g = ~68 px (cerca de 4 tiles)
const JUMP_CUT := 0.45          # soltar o botão corta a subida
const MAX_FALL_SPEED := 420.0
const COYOTE_TIME := 0.1
const JUMP_BUFFER := 0.1
const BIRD_BOX := Vector2(12, 14)
const DEATH_RESTART_TIME := 1.0  # a fase reinicia depois disso (a animação cabe nele)

# --- Bicudinho: planar --------------------------------------------------------
## Ação segurada para planar enquanto cai. Para usar outra tecla, crie a ação
## (por exemplo "glide") no Mapa de Entrada e troque o nome aqui.
const GLIDE_ACTION := &"move_up"
const GLIDE_FALL_SPEED := 110.0  # velocidade máxima de queda planando (px/s)
const GLIDE_BRAKE := 1500.0      # quão rápido ele freia ao começar a planar
const GLIDE_TIME := 0.6          # segundos de planar por pulo (volta ao tocar o chão)

# --- Bicudinho: preparar voo e disparada --------------------------------------
const PREPARE_MIN_AIR_TIME := 0.12      # tempo no ar antes de poder preparar
const PREPARE_GROUND_CLEARANCE := 12.0  # perto do chão, o 2º toque não prepara
const PREPARE_TIME := 0.15              # a pausa em que ele mira
const PREPARE_GRAVITY_SCALE := 0.05     # fração da gravidade durante a pausa
const DASH_SPEED := 400.0
const DASH_DISTANCE := 80.0             # 5 tiles
const DASH_EXIT_SPEED_SCALE := 0.35     # velocidade que sobra ao fim da disparada
const STUN_TIME := 0.5                  # atordoado ao bater no vidro
## Bater de lado na terra a até esta altura (px) abaixo do topo sobe na quina
## em vez de escorregar. Vale para a disparada e para o pulo. Nunca no vidro.
const LEDGE_ASSIST := 12.0

enum GlassRule { BLOCK, STUN, KILL }
## Regra única do vidro (para a disparada): BLOCK só bloqueia, STUN atordoa, KILL mata.
const GLASS_RULE := GlassRule.STUN

# --- Bicudinho: arte ----------------------------------------------------------
## Soma no Y do sprite. Positivo desce, negativo sobe. Use se ele aparecer
## flutuando ou afundado no chão (a base da imagem fica nos pés).
const SPRITE_Y_ADJUST := 2.0
const WALK_FPS := 10.0
const IDLE_FPS := 3.0
const FALL_FPS := 10.0           # a queda repete enquanto ele cai
const GLIDE_FPS := 10.0          # planar: bater de asas
const PREPARE_FPS := 20.0        # 3 quadros em ~0,15 s
const DASH_FPS := 16.0
const JUMP_FPS := 12.0           # o pulinho toca uma vez e fica no último quadro
const DEAD_FPS := 6.0            # a morte toca uma vez (4 quadros em ~0,67 s)

# --- Sons ---------------------------------------------------------------------
## Volume dos passos em dB (0 = original, -6 = metade, mais negativo = mais baixo).
const STEP_VOLUME_DB := -14.0
## Volume do som de vitória da fase em dB.
const WIN_VOLUME_DB := -12.0
## Quantos passos tocam por segundo enquanto ele anda.
const STEPS_PER_SECOND := 4.0

# --- Janela do jogo e vidro ---------------------------------------------------
const GLASS_THICKNESS := 3.0     # espessura visual do vidro (moldura preta + cinza)
const GLASS_COLLIDER := 16.0     # espessura da colisão (maior, para não ser atravessada)
const TITLEBAR_H := 24.0         # painel azul: borda de 4 + botão de 16 + borda de 4
const RESIZE_SPEED := 360.0      # px/s: limite de velocidade ao redimensionar
const RESIZE_GRAB := 6.0         # largura da faixa de arrasto na borda
const RESIZE_CORNER := 12.0      # tamanho da zona de canto
const SNAP := 16.0               # o tamanho da janela anda de 16 em 16 px
