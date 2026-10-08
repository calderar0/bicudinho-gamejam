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
const DEATH_RESTART_TIME := 1.0

# --- Bicudinho: arte ----------------------------------------------------------
## Soma no Y do sprite. Positivo desce, negativo sobe. Use se ele aparecer
## flutuando ou afundado no chão (a base da imagem fica nos pés).
const SPRITE_Y_ADJUST := 2.0
const WALK_FPS := 10.0
const IDLE_FPS := 3.0

# --- Janela do jogo e vidro ---------------------------------------------------
const GLASS_THICKNESS := 4.0     # espessura visual do vidro
const GLASS_COLLIDER := 16.0     # espessura da colisão (maior, para não ser atravessada)
const TITLEBAR_H := 12.0
const RESIZE_SPEED := 360.0      # px/s: limite de velocidade ao redimensionar
const RESIZE_GRAB := 6.0         # largura da faixa de arrasto na borda
const RESIZE_CORNER := 12.0      # tamanho da zona de canto
const SNAP := 16.0               # o tamanho da janela anda de 16 em 16 px
