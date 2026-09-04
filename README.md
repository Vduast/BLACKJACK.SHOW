# BLACKJACK.SHOW

Videojuego de Blackjack (21) en 3D, multijugador en red local, desarrollado con **Godot Engine 4.x (GDScript)**. Incluye modo un jugador contra la casa (PvE) y modo jugador contra jugador (PvP), mesa 3D con crupier animado, sistema de cartas visuales con efectos de shader, y un sistema de comodines ("Jokers") con habilidades especiales.

---

## Tabla de contenidos

1. [Descripción general](#descripción-general)
2. [Tecnología utilizada](#tecnología-utilizada)
3. [Estructura del proyecto](#estructura-del-proyecto)
4. [Arquitectura y flujo del juego](#arquitectura-y-flujo-del-juego)
5. [Configuración del proyecto (project.godot)](#configuración-del-proyecto-projectgodot)
6. [Autoloads (Singletons)](#autoloads-singletons)
7. [Documentación de scripts y funciones](#documentación-de-scripts-y-funciones)
   - [NetworkManager.gd](#networkmanagergd)
   - [table.gd](#tablegd)
   - [tableui.gd](#tableuigd)
   - [player.gd](#playergd)
   - [Dealer.gd](#dealergd)
   - [card_3d.gd](#card_3dgd)
   - [Deck.gd](#deckgd)
   - [JokerUI.gd](#jokeruigd)
   - [score_board_3d.gd](#score_board_3dgd)
   - [score_board_ui.gd](#score_board_uigd)
   - [fadelayer.gd (Transition)](#fadelayergd-transition)
   - [MenuUi.gd](#menuuigd)
   - [lobbyui.gd](#lobbyuigd)
   - [PantallaInteractiva.gd](#pantallainteractivagd)
8. [Sistema de Comodines (Jokers)](#sistema-de-comodines-jokers)
9. [Sistema de red (Multijugador)](#sistema-de-red-multijugador)
10. [Shaders y efectos visuales](#shaders-y-efectos-visuales)
---

## Descripción general

BLACKJACK.SHOW simula una mesa de casino de Blackjack con:

- Un **crupier (dealer) 3D animado**, que reparte cartas, mira a los jugadores y "habla" mediante animaciones proceduales.
- **Cartas 3D con efecto de disolución/aparición** mediante shaders personalizados.
- Un sistema de **multijugador en red local (LAN)** basado en `ENetMultiplayerPeer`, con generación de "códigos de sala" a partir de la IP del anfitrión.
- Dos modos de juego:
  - **PvE (un jugador o cooperativo contra la casa):** los jugadores compiten contra el dealer.
  - **PvP (jugador contra jugador):** cuando hay más de un jugador conectado, compiten entre ellos por la puntuación más alta.
- Un sistema de **vidas/derrotas** (`player_losses`) que elimina a un jugador tras acumular cierto número de derrotas.
- Un sistema de **comodines especiales ("Jokers")** con efectos que alteran el mazo o las derrotas de los jugadores.
- Menús con navegación, configuración de audio (buses Master/SFX/Music/Voz) y transición de escenas.

---

## Tecnología utilizada

| Componente | Detalle |
|---|---|
| Motor | Godot Engine 4.x |
| Lenguaje | GDScript |
| Plataforma de salida | Android (`Blackjack.apk.idsig` presente en el repo) |
| Red | `ENetMultiplayerPeer` (multijugador nativo de Godot), RPCs (`@rpc`) |
| Gráficos | Shaders personalizados (`dissolve_card.gdshader`), materiales 3D, `SubViewport` para renderizar UI 2D sobre mallas 3D |
| Audio | Sistema de *pooling* de reproductores de sonido, buses de audio configurables (Master, SFX, Music, Voz) |

Visualmente, el juego apunta a una **estética retro/VHS de casino ochentero**: usa un pipeline de post-procesado con efectos de VHS, distorsión de lente, nitidez y corrección de color (addon `godot_retro`), un addon `crt` adicional, reducción de profundidad de color estilo PS1 (`color_grade.gdshader`), niebla volumétrica y shaders "sucios/vintage" (mugre, desgaste de papel) aplicados a fondos, mesa y elementos de UI.

---

## Estructura del proyecto

```
BLACKJACK.SHOW/
├── Animations/        # Animaciones de personajes/objetos
├── Menus/              # Escenas de menú (MainMenu, etc.)
├── Objetos/            # Escenas de objetos instanciables (Player.tscn, Card3D.tscn, Table.tscn, JokerUI.tscn, etc.)
├── Scripts/            # Lógica en GDScript (ver documentación abajo)
├── addons/              # Complementos/plugins de Godot
├── models/              # Modelos 3D y fuentes
├── shaders/             # Shaders personalizados (ej. dissolve_card.gdshader)
├── sounds/              # Efectos de sonido y música
├── textures/            # Texturas (incluye símbolos de palos: hearts, diamonds, clubs, spades)
├── project.godot        # Configuración principal del proyecto Godot
├── Blackjack.apk.idsig   # Firma de compilación Android
├── Blackjack.pck         # Paquete de recursos exportado
└── Blackjack.zip         # Build empaquetado
```

---

## Configuración del proyecto (project.godot)

A partir del archivo `project.godot` se confirman los siguientes datos técnicos:

| Parámetro | Valor |
|---|---|
| Nombre de la aplicación | `Blackjack` |
| Versión de Godot | `4.7` (Forward+ renderer) |
| Resolución de ventana | `1920 x 1080`, modo `3` (pantalla completa), no redimensionable |
| VSync | Desactivado (`vsync_mode = 0`) |
| Driver de renderizado (Windows) | `d3d12` |
| Plugins habilitados | `godot_retro` (efectos de compositor retro), `script-ide` (entorno de edición de scripts) |
| Shader globals | Parámetros PSX globales (`psx_affine_strength`, `psx_bit_depth`, `psx_fog_*`, `vertex_snap_intensity`, etc.) — confirman un **estilo visual retro tipo PlayStation 1** aplicado de forma global a los shaders del proyecto |
| Grupo global | `cartas` — grupo usado para identificar todas las cartas 3D en escena (usado por `table.gd` para animar la limpieza de mesa) |

---

## Autoloads (Singletons)

El proyecto define 4 autoloads globales (accesibles desde cualquier script sin necesidad de referencia directa):

| Autoload | Script / Escena | Rol |
|---|---|---|
| `NetworkManager` | `NetworkManager.gd` | Gestión completa de la conexión multijugador (ver documentación abajo). |
| `PantallaInteractiva` | `PantallaInteractiva.gd` | Sistema para proyectar y controlar interfaces 2D sobre superficies 3D. |
| `Transition` | `fadelayer.gd` | Capa global de fundido a negro (fade in/out) usada en cada cambio de escena del juego. |
| `ColorGrade` | `color_grade.tscn` / `color_grade.gdshader` | Overlay de pantalla completa que aplica posterización de color (reducción de profundidad de color) para lograr una estética retro tipo PS1; no tiene script propio, es un `ColorRect` con `ShaderMaterial`. |

---

## Arquitectura y flujo del juego

1. **Menú principal (`MenuUi.gd`)**: el jugador elige entre un jugador o multijugador, configura su nombre, aloja o se une a una partida mediante un código de sala, y ajusta configuraciones de audio.
2. **Conexión de red (`NetworkManager.gd`)**: gestiona la creación del servidor/host o la conexión como cliente, sincroniza la lista de jugadores y soporta **migración de host** si el anfitrión se desconecta.
3. **Lobby (`lobbyui.gd` / parte de `MenuUi.gd`)**: muestra el código de sala y los jugadores conectados; el host inicia la partida.
4. **Mesa de juego (`table.gd` + `tableui.gd`)**: controla toda la lógica de una ronda de Blackjack — construir y barajar el mazo, repartir cartas, turnos de Hit/Stand/Double, cálculo de puntuación, uso de comodines, evaluación de ganadores (PvE o PvP), y actualización de un marcador 3D.
5. **Visualización de cartas (`card_3d.gd`, `Deck.gd`)**: genera visualmente cada carta (rango, palo, símbolos) y aplica animaciones de aparición/desaparición mediante shader.
6. **Dealer (`Dealer.gd`)**: anima brazos, cabeza (mirar al jugador activo) y "habla" del crupier durante el reparto y los anuncios.
7. **Comodines (`JokerUI.gd`)**: cada jugador recibe 3 comodines al inicio de la partida con efectos únicos que pueden usar una vez por comodín.

---

## Documentación de scripts y funciones

### `NetworkManager.gd`
**Hereda de:** `Node` — Autoload/Singleton global de red.

Gestiona toda la capa de conexión multijugador: creación de servidor, conexión de clientes, sincronización de la lista de jugadores, migración de host y generación/decodificación de códigos de sala.

**Señales**
- `players_updated` — se emite cuando cambia la lista de jugadores conectados.
- `connection_succeeded` — se emite cuando un cliente se conecta exitosamente al host.
- `connection_failed` — se emite si la conexión falla o expira por tiempo.

**Variables clave**
- `PORT` (const `8080`) — puerto de red usado por el servidor.
- `peer` — instancia de `ENetMultiplayerPeer`.
- `players` (`Dictionary`) — mapa `id → {name, ip}` de jugadores conectados.
- `my_info`, `my_id` — datos e identificador del jugador local.
- `is_in_game`, `is_connecting`, `game_mode` — estados de la sesión.

**Funciones**
| Función | Descripción |
|---|---|
| `_ready()` | Conecta las señales nativas de `multiplayer` (peer conectado/desconectado, conexión exitosa/fallida, servidor desconectado). |
| `start_singleplayer(player_name)` | Configura el modo un jugador: aloja una partida local y realiza la transición a la escena de la mesa. |
| `host_game(player_name)` | Crea un servidor ENet en el puerto definido y registra al host como jugador `1`. |
| `join_game(ip, player_name)` | Intenta conectar como cliente a la IP indicada; incluye un timeout de 5 segundos para cancelar si no hay respuesta. |
| `_on_peer_connected(id)` | Envía (`rpc_id`) la información propia al nuevo peer conectado. |
| `_on_peer_disconnected(id)` | Elimina al jugador desconectado de la lista y notifica el cambio. |
| `_on_connected_to_server()` | Marca la conexión como exitosa, obtiene el ID de red propio y se registra ante el host. |
| `_on_connection_failed()` | Limpia el estado de conexión y emite `connection_failed`. |
| `register_player(info)` *(RPC)* | El host registra a un nuevo jugador y sincroniza la lista completa a todos los peers. |
| `sync_players(all_players)` *(RPC)* | Actualiza la lista local de jugadores recibida del host. |
| `start_game()` *(RPC)* | Marca el inicio de partida y transiciona a la escena de la mesa. |
| `_on_server_disconnected()` | Lógica de **migración de host**: si el host se cae, el jugador con el ID más bajo restante se convierte en el nuevo host; si no queda nadie, regresa al menú principal. |
| `reload_game_scene()` *(RPC)* | Recarga la escena actual (usado tras una migración de host). |
| `get_local_ip()` | Detecta la IP local (LAN) del dispositivo entre los rangos privados comunes. |
| `ip_to_int(ip)` / `int_to_ip(n)` | Convierte una IP a un entero de 32 bits y viceversa. |
| `generate_room_code()` | Genera un código de sala en **Base62** de 6 caracteres a partir de la IP local del host. |
| `decode_room_code(code)` | Decodifica un código Base62 de vuelta a una dirección IP para poder conectarse. |

---

### `table.gd`
**Hereda de:** `Node3D` — Controlador principal de una ronda de Blackjack (autoridad del servidor sobre la lógica del juego).

Es el script más extenso del proyecto: gestiona el mazo, el reparto, los turnos, la puntuación, el sistema de vidas, los modos PvE/PvP, los comodines y el marcador 3D.

**Variables clave**
- `deck_cards`, `hands`, `dealer_hand` — estado del mazo y las manos.
- `active_players`, `players_done`, `player_losses`, `max_losses` — control de jugadores activos y su historial de derrotas (vidas).
- `players_requesting_card`, `players_stood`, `players_doubled` — control de acciones por ronda.
- `is_pvp_mode` — determina si la ronda se evalúa contra el dealer o entre jugadores.

**Funciones principales**
| Función | Descripción |
|---|---|
| `_ready()` | Inicializa el pool de audio, conecta señales de la UI y de red, posiciona los asientos de jugadores y arma el mazo si es el servidor. |
| `get_player_name(id)` | Devuelve el nombre de un jugador de forma segura (protección ante claves numéricas/string). |
| `play_sfx(stream, randomize_pitch)` | Reproduce un efecto de sonido usando *pooling* de reproductores con variación de tono. |
| `_make_dealer_look_at_random_player()` | Hace que el dealer mire aleatoriamente a un jugador activo. |
| `_spawn_seat_visual_local(id, index)` | Instancia visualmente el asiento/personaje de un jugador y ajusta cámaras. |
| `_position_seat(seat, index)` | Posiciona el asiento en un punto de spawn y lo orienta hacia el dealer. |
| `update_all_cameras()` | Ajusta la cámara de cada jugador para enfocar entre su mano y el dealer. |
| `_on_clear_pressed()` / `prepare_for_new_round()` *(RPC)* | Limpia la mesa y prepara una nueva ronda. |
| `_on_start_pressed()` | Inicia una ronda: reparte comodines (primera ronda), construye el mazo, reparte 2 cartas a cada jugador y al dealer, revisa Blackjack automático. |
| `animate_table_cleanup()` *(RPC)* | Anima al dealer recogiendo/haciendo desaparecer las cartas de la mesa entre rondas. |
| `_build_deck()` | Construye un mazo estándar de 52 cartas y lo baraja. |
| `deal_card(target_id, is_hidden)` | Reparte una carta a un jugador o al dealer (con opción de carta oculta / "hole card"); reconstruye el mazo si se agota. |
| `calculate_score(hand)` | Calcula la puntuación de una mano aplicando la regla especial del As (11 u 1 según convenga). |
| `_on_double_pressed()` / `request_double()` *(RPC)* | Lógica de "doblar apuesta": solo permitido con exactamente 2 cartas; reparte una carta adicional y termina el turno. |
| `_on_hit_pressed()` / `request_hit()` *(RPC)* | Lógica de "pedir carta"; termina el turno automáticamente si se llega a 21 o más. |
| `_on_stand_pressed()` / `request_stand()` *(RPC)* | Lógica de "plantarse". |
| `player_finished_turn(peer_id)` | Marca a un jugador como terminado; si todos terminaron, evalúa ganadores (PvP o turno del dealer). |
| `reveal_dealer_hole_card()` *(RPC)* | Anima el giro de la carta oculta del dealer para revelarla. |
| `play_dealer_turn()` | El dealer pide cartas automáticamente hasta alcanzar al menos 17 puntos. |
| `evaluate_winners_pvp()` | Evalúa la ronda en modo jugador contra jugador: determina la puntuación más alta, empates y aplica derrotas/eliminación. |
| `evaluate_winners_pve(dealer_score)` | Evalúa la ronda en modo jugador contra la casa: compara cada mano contra el dealer y aplica resultados (gana, pierde, empata, Blackjack). |
| `_finalize_round(...)` | Elimina jugadores derrotados, arma el mensaje global de resultado y notifica reinicio de ronda o de partida completa. |
| `trigger_outro_music()` | Ajusta la música para el cierre de partida. |
| `sync_card_visual(...)` *(RPC)* | Sincroniza visualmente en todos los clientes la aparición de una carta repartida (incluye animación del dealer). |
| `update_player_score(target_id, score)` *(RPC)* | Actualiza visualmente la puntuación de un jugador. |
| `receive_jokers_ui(joker_list)` *(RPC)* | Envía al cliente la lista de comodines que le tocaron. |
| `_on_joker_used(effect_id)` / `request_use_joker(effect_id)` *(RPC)* | Solicita al servidor ejecutar el efecto de un comodín. |
| `request_use_joker` — lógica interna | Implementa los 10 efectos posibles de comodín (ver [sección de Jokers](#sistema-de-comodines-jokers)). |
| `update_scoreboard_logic()` / `sync_scoreboard(...)` *(RPC)* | Recalcula y sincroniza los datos del marcador 3D (nombre, vidas, puntuación de cada jugador). |

---

### `tableui.gd`
**Hereda de:** `CanvasLayer` — Interfaz de usuario 2D superpuesta durante la partida (HUD).

**Señales**
`start_game`, `hit_pressed`, `stand_pressed`, `clear_pressed`, `joker_used(effect_id)`, `double_pressed`.

**Funciones principales**
| Función | Descripción |
|---|---|
| `_ready()` | Conecta botones a sus señales, inicializa sliders de audio y aplica animaciones "juice" a los botones. |
| `_apply_button_juice(node)` / `_animate_button_hover(btn, is_hovered)` | Aplica un efecto de escalado suave al pasar el ratón sobre cualquier botón de la UI. |
| `_on_open_menu_pressed()` / `_on_continue_pressed()` / `_on_settings_pressed()` / `_on_back_pressed()` / `_on_exit_pressed()` | Navegación del menú de pausa superpuesto (incluye salir a menú principal y limpiar la sesión de red). |
| `_on_master_volume_changed` / `_on_sfx_volume_changed` / `_on_music_volume_changed` / `_on_voz_volume_changed` | Controlan el volumen de los buses de audio correspondientes. |
| `set_status(text)` | Cambia el texto de estado en pantalla. |
| `transition_to_game(message)` | Muestra el panel de juego y oculta los botones de inicio/limpieza. |
| `show_start_button(text)` / `hide_start_button()` / `show_clear_button()` / `hide_clear_button()` / `hide_game_panel()` | Controlan la visibilidad de elementos de la interfaz según el estado de la partida. |
| `spawn_jokers(joker_ids)` | Instancia los botones de comodín asignados al jugador, con nombre y descripción de cada efecto. |
| `_on_joker_selected(joker)` | Selecciona un comodín, gira su tarjeta para mostrar la descripción y despliega la caja de confirmación. |
| `_on_joker_canceled()` | Cancela la selección de un comodín. |
| `_on_joker_confirmed()` | Confirma el uso del comodín seleccionado, dispara su animación de "quemado" y notifica al servidor. |

---

### `player.gd`
**Clase:** `PlayerSeat` — **Hereda de:** `Node3D`. Representa el asiento y avatar de un jugador en la mesa.

| Función | Descripción |
|---|---|
| `setup(player_id_raw)` | Configura la etiqueta de nombre/puntuación y activa la cámara si el asiento corresponde al jugador local. |
| `add_visual_card(card_instance)` | Añade una carta 3D a la mano visual del jugador y reordena todas sus cartas. |
| `reset_ui()` | Reinicia la puntuación visible y limpia la lista de cartas visuales. |
| `_rearrange_cards()` | Recalcula la posición de cada carta en abanico según la cantidad total en mano. |
| `adjust_camera(all_seats, dealer_pos)` | Orienta suavemente la cámara del jugador hacia el punto medio entre el dealer y sus propias cartas. |
| `update_score_display(score)` | Actualiza el texto de puntuación, marcando visualmente "Voló" (bust) o "¡Blackjack!" según corresponda. |
| `set_result(result_text, color)` | Muestra el resultado final de la ronda (victoria/derrota/empate) con color asociado. |

---

### `Dealer.gd`
**Clase:** `DealerAnim` — **Hereda de:** `Node3D`. Controla la animación procedural del crupier 3D.

| Función | Descripción |
|---|---|
| `_ready()` | Guarda las posiciones de descanso de los brazos, activa el árbol de animaciones y localiza el hueso de la cabeza en el esqueleto. |
| `_process(_delta)` | Aplica en cada frame la rotación de la cabeza hacia el objetivo de mirada (`look_target`), con corrección de ejes. |
| `deal_to_position(target_position)` | Determina qué brazo (derecho/izquierdo) está más cerca del destino y anima el movimiento de reparto de carta. |
| `_animate_arm(side, target_node, rest_pos, final_pos)` | Anima el brazo elegido: movimiento rápido hacia el destino, pausa y regreso elástico a la posición de reposo, junto con transiciones en el árbol de animación. |
| `speak(is_active)` | Activa/desactiva la mezcla de animación de "hablar" del dealer. |
| `look_at_target(target)` | Hace que el dealer mire hacia la cámara del jugador activo (o el objetivo indicado) con una transición rápida. |
| `stop_looking()` | Detiene gradualmente el seguimiento de mirada del dealer. |

---

### `card_3d.gd`
**Clase:** `Card3D` — **Hereda de:** `Node3D`. Representa visualmente una carta individual en 3D, incluyendo su generación gráfica y efectos de shader.

| Función | Descripción |
|---|---|
| `_ready()` | Crea dinámicamente un `ShaderMaterial` con el shader de disolución, le asigna la textura generada por el `SubViewport` y una textura de ruido, y lanza la animación de aparición. |
| `aparecer()` | Anima la carta desde un estado "disuelto" (invisible, borde grueso y brillante) hasta su estado sólido final. |
| `desaparecer()` | Anima la disolución inversa de la carta (con posible efecto de partículas) y la elimina de la escena al terminar. |
| `_set_dissolve(value)` / `_set_edge_thickness(value)` / `_set_glow_intensity(value)` | Funciones auxiliares que permiten animar parámetros del shader mediante `Tween`. |
| `set_card(data)` | Asigna los datos (rango, palo, valor) a la carta y dispara la generación visual del rango y los símbolos. |
| `_apply_rank()` | Escribe el texto del rango en las esquinas superior e inferior de la carta. |
| `_generate_symbols()` | Genera dinámicamente los símbolos del palo (corazones, diamantes, tréboles, picas) según el valor de la carta. |
| `_get_symbol_positions(count)` | Devuelve las posiciones (layout) de los símbolos según la cantidad requerida (1 a 10), replicando la disposición clásica de una baraja. |

---

### `Deck.gd`
**Clase:** `Deck` — **Hereda de:** `Node`. Representa un mazo de cartas genérico (lógica reutilizable, independiente de `table.gd`, que también implementa su propia versión interna del mazo).

| Función | Descripción |
|---|---|
| `build_deck()` | Genera las 52 cartas estándar (4 palos × 13 rangos) con su valor numérico correspondiente. |
| `shuffle()` | Baraja aleatoriamente el mazo. |
| `draw_card()` | Extrae y devuelve la primera carta del mazo (`Dictionary` vacío si no quedan cartas). |

---

### `JokerUI.gd`
**Clase:** `JokerUI` — **Hereda de:** `Button`. Representa visualmente un comodín individual y sus animaciones.

**Señal:** `joker_selected(nodo_carta)`

| Función | Descripción |
|---|---|
| `setup(effect_id, nombre_mostrar, desc)` | Configura el identificador de efecto, título y descripción del comodín, aplicando estilos de fuente y color. |
| `_pressed()` | Emite la señal `joker_selected` al pulsar el botón. |
| `girar_a_descripcion()` | Anima un giro 3D (escala en X) para mostrar la descripción del comodín. |
| `girar_a_titulo()` | Anima el giro inverso para volver a mostrar el título. |
| `quemar_y_destruir()` | Anima un efecto de "quemado" mediante shader y destruye el nodo del comodín tras usarlo. |

---

### `score_board_3d.gd`
**Hereda de:** `Node3D`. Es la contraparte 3D del marcador: proyecta la interfaz `ScoreBoardUI` (2D, vía `SubViewport`) sobre una malla 3D visible en la mesa, con emisión de luz propia para que se lea como una pantalla/tótem luminoso.

| Función | Descripción |
|---|---|
| `_ready()` | Crea un `StandardMaterial3D` con la textura del `SubViewport` como *albedo* y como *emission* (multiplicador de energía 2.0), y lo aplica a la malla del marcador. |
| `refresh_board(data, dealer_score)` | Reenvía los datos de jugadores y la puntuación del dealer a la interfaz 2D interna (`ScoreBoardUI.update_data`). |
| `show_temporary_status(text)` | Reenvía un mensaje de estado temporal a la interfaz 2D interna (`ScoreBoardUI.flash_status`). |

---

### `score_board_ui.gd`
**Clase:** `ScoreBoardUI` — **Hereda de:** `Control`. Interfaz 2D que lista en tiempo real a los jugadores activos (nombre, vidas, puntuación) y al dealer, renderizada dentro del `SubViewport` de `score_board_3d.gd`.

| Función | Descripción |
|---|---|
| `_ready()` | Oculta la etiqueta de estado temporal al iniciar. |
| `update_data(players_data, dealer_score)` | Guarda los datos recibidos y reconstruye la lista visual. |
| `_rebuild_list()` | Limpia y vuelve a generar las etiquetas de cada jugador (❤️ vidas, 🃏 puntos) y, si corresponde, del dealer (🎩). |
| `flash_status(message, seconds)` | Oculta temporalmente la lista de jugadores y muestra un mensaje grande centrado (ej. "Dealer's turn...") durante los segundos indicados, luego revierte automáticamente. |

---

### `fadelayer.gd` (Transition)
**Hereda de:** `CanvasLayer` — **Autoload:** `Transition`. Capa global de fundido a negro utilizada en cada cambio de escena del juego (menú → mesa, mesa → menú, migración de host, etc.).

| Función | Descripción |
|---|---|
| `_ready()` | Inicia la capa completamente en negro y ejecuta un fundido de entrada (`fade_in`) al arrancar el juego. |
| `fade_in()` | Anima la opacidad del rectángulo de fundido de 1.0 (negro) a 0.0 (transparente) en `FADE_TIME` (0.5s). |
| `fade_to_scene(scene_path)` | Funde a negro, cambia a la escena indicada (`change_scene_to_file`) y vuelve a hacer fundido de entrada. Es la función invocada como `Transition.fade_to_scene(...)` desde `NetworkManager.gd`. |

---

### `MenuUi.gd`
**Hereda de:** `Control`. Controla el menú principal completo: selección de modo, conexión multijugador, lobby y configuración.

| Función | Descripción |
|---|---|
| `_ready()` | Crea el pool de audio, conecta señales de `NetworkManager`, sliders de configuración, y muestra la caja de selección de modo por defecto. |
| `play_sfx(stream, randomize_pitch)` | Reproduce efectos de sonido con *pooling* y variación de tono (round-robin). |
| `_apply_button_juice(node)` / `_animate_button_hover(btn, is_hovered)` | Aplica animaciones de hover/clic a todos los botones del menú recursivamente. |
| `play_transition_and_start(callback)` | Reproduce una transición inmersiva de cámara (zoom + fundido a negro) antes de ejecutar una función de callback (usada al iniciar partida). |
| `_hide_all_boxes()` | Oculta todos los paneles del menú. |
| `_change_menu(new_box)` | Cambia el panel visible actual y guarda un historial de navegación. |
| `_on_back_pressed()` | Regresa al panel anterior; si se sale del lobby, cierra la conexión de red activa. |
| `_on_quit_pressed()` | Cierra la aplicación. |
| `_on_singleplayer_pressed()` | Inicia el modo un jugador. |
| `_on_multiplayer_pressed()` | Cambia al panel de conexión multijugador. |
| `_on_open_settings_pressed()` | Abre el panel de configuración. |
| `_on_host_pressed()` | Aloja una partida y navega al lobby. |
| `_on_join_pressed()` | Decodifica el código de sala ingresado y se conecta a esa IP; muestra error si el código es inválido. |
| `_on_connection_success()` / `_on_connection_failed()` | Manejan el resultado de un intento de conexión. |
| `_show_error(msg)` | Muestra un mensaje de error y reproduce un sonido asociado. |
| `_set_ui_disabled(disabled)` | Habilita/deshabilita los controles de conexión mientras se procesa una solicitud. |
| `_update_lobby_ui()` | Actualiza el código de sala mostrado y la lista de jugadores conectados en el lobby. |
| `_on_start_pressed()` | El host solicita al `NetworkManager` iniciar la partida para todos los clientes. |
| `_on_master_volume_changed` / `_on_sfx_volume_changed` / `_on_music_volume_changed` / `_on_voz_volume_changed` | Ajustan los buses de audio correspondientes. |

---

### `lobbyui.gd`
**Hereda de:** `Control`. Versión simplificada de la interfaz de lobby (posiblemente una escena independiente reutilizada o una versión anterior a la integrada en `MenuUi.gd`).

| Función | Descripción |
|---|---|
| `_ready()` | Conecta la actualización de lobby a los cambios de jugadores y al botón de inicio. |
| `_update_lobby_ui()` | Muestra el código de sala (si es host) o el estado de espera (si es cliente), y actualiza la lista de jugadores. |
| `_on_start_pressed()` | Solicita al `NetworkManager` iniciar la partida (`rpc("start_game")`). |

---

### `PantallaInteractiva.gd`
**Hereda de:** `Area3D`. Permite proyectar un `SubViewport` (interfaz 2D) sobre una malla 3D y redirigir la interacción del ratón/teclado hacia ese viewport — utilizado probablemente para pantallas interactivas dentro del entorno 3D (ej. un menú o marcador dentro del mundo del juego).

| Función | Descripción |
|---|---|
| `_ready()` | Asigna la textura renderizada del `SubViewport` como textura de la malla 3D (crea un material si no existe). |
| `_input_event(...)` | Traduce la posición del clic del ratón en el espacio 3D a coordenadas UV/píxeles del viewport, e inyecta el evento dentro de él (con múltiples validaciones de seguridad ante nodos eliminados). |
| `_unhandled_input(event)` | Redirige eventos de teclado no manejados hacia el `SubViewport`. |

---

## Sistema de Comodines (Jokers)

Al iniciar la primera ronda, cada jugador recibe **3 comodines aleatorios** (pueden repetirse) de un total de 10 efectos posibles, gestionados en `table.gd::request_use_joker()` y presentados visualmente en `tableui.gd::spawn_jokers()`:

| ID | Nombre | Efecto |
|---|---|---|
| `burn` | 🔥 Quemar | Destruye la carta en la cima del mazo. |
| `peek` | 👁️ Visión | Revela en secreto (solo al usuario) la siguiente carta del mazo. |
| `shield` | 🛡️ Amnesia | Elimina 1 derrota del historial propio. |
| `shuffle` | 🔄 Mezclar | Baraja todo el mazo nuevamente. |
| `prophecy` | 🔮 Profecía | Revela en secreto las siguientes 3 cartas del mazo. |
| `sabotage` | 💣 Sabotaje | Coloca una carta "10 de picas" en la cima del mazo. |
| `curse` | ☠️ Maldición | Suma +1 derrota a todos los demás jugadores activos. |
| `salvation` | 👼 Salvación | Elimina hasta 2 derrotas del historial propio de golpe. |
| `bury` | 🕳️ Enterrar | Mueve la carta superior del mazo hasta el fondo. |
| `expose` | 🚨 Exponer | Revela públicamente (a todos) la siguiente carta del mazo. |

Cada comodín solo puede usarse una vez; al confirmarse su uso, se destruye visualmente mediante la animación `quemar_y_destruir()`.

---

## Sistema de red (Multijugador)

- Basado en el sistema nativo de **alto nivel de multijugador de Godot** (`ENetMultiplayerPeer` + `@rpc`).
- El **host** siempre actúa como servidor autoritativo: toda la lógica de juego en `table.gd` valida `multiplayer.is_server()` antes de ejecutar cambios de estado.
- Los jugadores se conectan mediante una **IP directa** o un **código de sala Base62 de 6 caracteres**, generado/decodificado a partir de la IP local del host (`NetworkManager.generate_room_code()` / `decode_room_code()`).
- Incluye **migración de host**: si el servidor se desconecta, el cliente con el ID numérico más bajo restante se convierte automáticamente en el nuevo host y recarga la escena de juego para los demás.
- El modo de juego (`PvE` o `PvP`) se determina automáticamente según la cantidad de jugadores conectados (`is_pvp_mode = NetworkManager.players.size() > 1`).

---

## Shaders y efectos visuales

El proyecto usa un número considerable de shaders personalizados (`.gdshader`) para lograr su identidad visual "retro/vintage de casino":

| Shader | Tipo | Propósito |
|---|---|---|
| `dissolve_card.gdshader` | Spatial (3D) | Efecto de disolución/materialización de las cartas (usado por `card_3d.gd` en `aparecer()`/`desaparecer()`). |
| `Card3D.gdshader` / `table_ui.gdshader` | Canvas item (2D) | Textura de "papel envejecido" (ruido + tinte cálido) aplicada sobre elementos de UI tipo StyleBox. |
| `suitshaders.gdshader` | Spatial | Colorea los símbolos de palo (rojo para corazones/diamantes, negro para tréboles/picas) sobre una textura base. |
| `JokerUI.gdshader` | Canvas item | Efecto de "quemado" con textura de papel y patrón de fuego procedural (ruido), usado al destruir un comodín tras su uso. |
| `stylized.gdshader` | Spatial | Shader de iluminación "por pasos" (*cel-shading*/toon) con soporte de textura normal y especular configurable. |
| `color_grade.gdshader` | Canvas item (pantalla completa) | Posterización de color de toda la pantalla (reduce la profundidad de color, estética PS1); controlado por el autoload `ColorGrade`. |
| `Table.gdshader` | Canvas item (pantalla completa) | Efecto de granulado (grain), líneas de barrido (scanlines) y tinte holográfico/cian — refuerza la estética retro/VHS. |
| `FONDO.gdshader` / `ground.gdshader` | Spatial | Materiales procedurales del fondo/suelo con patrones geométricos, relieve (bump), mugre/desgaste y propiedades físicas realistas (rugosidad, metalicidad). |
| `MainMenu.gdshader` | Spatial | Material de pared/fondo del menú principal con relieve procedural, mugre y desgaste. |

Además, el proyecto integra dos addons de efectos visuales:
- **`addons/godot_retro`**: efectos de compositor (`vhs_effect.gd`, `lens_distortion_effect.gd`, `sharpness_effect.gd`, `color_correction_effect.gd`) aplicados como post-procesado global sobre la cámara 3D.
- **`addons/crt`**: efecto adicional de pantalla tipo monitor CRT.

Estos efectos, combinados con la niebla volumétrica configurada en el `WorldEnvironment` de la mesa (`Table.tscn`), conforman la dirección de arte general del juego: una mesa de casino con aspecto de transmisión de TV retro/VHS.

---
