extends Node
## Todos os números de ajuste do jogo ficam aqui. Balanceie sem caçar valores no código.
## Referência: pulo de 4 tiles de altura e 7 de distância, disparada de 5 tiles.

const TILE := 16

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
