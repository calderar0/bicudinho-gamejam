extends LevelBase
## O desktop principal: o jogo começa aqui. Cada fase é um .exe falso (duplo clique abre);
## só aparecem as liberadas (a 1 sempre, as outras depois de vencer a anterior). As pastas
## "gravetos" (a coleção), "fotos", "trabalho" e "créditos" ficam em todas as fases.
## Fechar a janela de uma fase volta para cá. Os .exe são criados pela LevelBase.


func _setup_level() -> void:
	is_hub = true
	level_name = "Desktop"
	window_rect = Rect2(560, 256, 48, 48)   # a janela do jogo fica escondida (minimizada)
	bird_start = Vector2(584, 304)          # o pássaro (escondido) nasce dentro dela
	exit_feet = Vector2(-100, -100)         # e a saída, longe de tudo
	twig_folder_pos = desktop_slot(0)
	desktop_folder_pos = {"fotos": desktop_slot(1), "trabalho": desktop_slot(2), "créditos": desktop_slot(3)}
	note_title = "leia-me.txt"
	note_text = "Bem-vindo ao Bicudinho!\n\nClique duas vezes num .exe para jogar.\nCada fase vencida libera a próxima, e cada graveto vai para a pasta \"gravetos\"."
	note_pos = Vector2(300, 60)
	note_size = Vector2(220, 100)


func _ready() -> void:
	super._ready()
	set_minimized(true, true)
