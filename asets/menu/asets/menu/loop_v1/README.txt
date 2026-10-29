Фон меню: 5 кадров, каждый 1920 × 1080, 4 кадра/сек, цикл 1,25 секунды.

Движется только вода; камера, персонажи и берег неподвижны.
Порядок: frame_01.png → frame_02.png → frame_03.png → frame_04.png → frame_05.png → frame_01.png.

Godot: назначить menu_loop.tres полю Sprite Frames узла AnimatedSprite2D и включить Autoplay (default).
Для отдельного просмотра открыть menu_loop_preview.tscn и запустить F6.
Готовое меню проекта не изменено.

preview.gif — уменьшенный предварительный просмотр 960 × 540.
spritesheet_5x1.png — пять кадров слева направо, 9600 × 1080.

Для повторной генерации нужен Node.js и пакет sharp: node build_loop.cjs.
