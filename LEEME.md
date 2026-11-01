<div align = center>

<img src="assets/header.svg" width="750" alt="Bitácora — una terminal que dibuja el propio escritorio">

<br>

La terminal del escritorio de [pleamar]: pestañas con un glifo propio, paneles
uno al lado del otro, los colores del escritorio, y los agentes que trabajan en
ella, distinguibles de un vistazo. Una escena de pleamar y unos cientos de
líneas de Luau, en un solo binario.

<br>

---

**[<kbd> <br> Instalar <br> </kbd>](#instalar)**
**[<kbd> <br> Teclas <br> </kbd>](#teclas)**
**[<kbd> <br> Con agentes <br> </kbd>](#con-agentes)**
**[<kbd> <br> pleamar <br> </kbd>][pleamar]**
**[<kbd> <br> pleamar-wm <br> </kbd>][pleamar-wm]**
**[<kbd> <br> Discord <br> </kbd>][Discord]**

---

<br>

<img src="assets/panes.webp" width="860" alt="Bitácora con cuatro pestañas, cada una con su glifo: la historia de pleamar con su grafo a la izquierda, un panel al lado con eza y git status, y la línea de abajo con la carpeta y la rama">

<sub>La historia de pleamar y un panel al lado. Cada pestaña lleva un glifo hecho de su carpeta; la línea de abajo dice dónde estás y en qué rama.</sub>

<br>
<br>

</div>

# Qué es

**La terminal en sí es de pleamar.** pleamar tiene un elemento `terminal`: un
shell en un pty, dibujado por el motor con sus propias letras, tan nítido como
cualquier texto de una escena y en sus colores (el emulador de debajo es
`alacritty_terminal`, el de Alacritty y Zed). Bitácora es la ventana a su
alrededor: una escena (`ui/bitacora.plm`) y su lógica (`ui/bitacora.luau`),
dentro de un solo binario con sus fuentes.

Funciona en **cualquier compositor de Wayland**: Hyprland, Sway, niri, KDE,
GNOME. Dentro de [pleamar-wm] sabe además en cuál de sus shells hay un agente
trabajando, preguntando o que ha terminado (ver [Con agentes](#con-agentes)).

# Galería

<div align = center>

<img src="assets/editor.webp" width="860" alt="vim en una pestaña de Bitácora, leyendo la escena de la propia Bitácora: sus eventos y sus teclas">

<sub>vim en una pestaña, en su otra pantalla, leyendo la escena de la propia Bitácora. Los programas que quieren el ratón lo tienen.</sub>

</div>

# Qué hace

- **Pestañas** (diez como mucho), cada una con el nombre de lo que corre en ella
  o de su carpeta, y un glifo de cinco por cinco granos hecho de esa carpeta: la
  misma carpeta, el mismo glifo, la veas donde la veas.
- **Paneles** (cuatro por pestaña): al lado o debajo, el que tiene el teclado
  marcado en el acento, los demás un poco más apagados. Un shell que acaba se
  lleva su panel; el último, la ventana.
- **La línea de abajo**: la carpeta del shell con el teclado, su rama de git, lo
  que corre y cuántas columnas y líneas.
- **Los colores del escritorio.** Si un shell publica su tema (acento,
  superficie y tinta, claro u oscuro), lo sigue en vivo, con los dieciséis
  colores ANSI ajustados a cada uno.
- **Lo que hace una buena terminal**: colores de 16, 256 y 24 bits, negrita,
  cursiva y subrayados; las líneas de caja y los bloques dibujados a mano para
  que encajen; seleccionar con el ratón (dos clics una palabra, tres una línea),
  Ctrl+Mayús+C y V, el botón del medio pega; la rueda por el historial y
  Ctrl+Mayús+F para buscar en él; Ctrl+clic abre un enlace; la otra pantalla de
  vim y less; y el cursor deja una estela tenue al escribir, sin ir nunca tarde.
- **El foco sigue al ratón** donde tu gestor de ventanas lo hace: la terminal de
  la ventana bajo el puntero coge el teclado, sin clic.

# Con agentes

En una sesión de pleamar-wm, Bitácora le pregunta cada segundo por sus shells
(`pleamar-wm term list --json`) y enseña lo que sabe. Fuera de ella es una
terminal normal, sin errores.

- **Una pestaña con un agente** (Claude Code, Codex…) toma el nombre de su tarea,
  y un punto dice cómo está: respira mientras trabaja, ámbar cuando te pregunta
  algo. Uno que acaba en una pestaña de atrás deja un punto, como una campana;
  la línea de abajo dice «Claude · trabajando».
- **Un agente al lado** (Ctrl+Mayús+A): un panel al lado del tuyo con Claude
  (`BITACORA_AGENT` dice otro), y un cable entre los dos (`pleamar-wm term
  pair`), un nudo de granos que lleva una ola mientras algo va por él. Para ese
  agente, tu panel es una ventana más cableada a la suya: lo lee y ejecuta cosas
  en él.
- **Enviar a…** (botón derecho): lo seleccionado, como carta a un agente con
  nombre (`pleamar-wm link post`).
- **Un equipo entero en una ventana.** `text open.name ID`, `text open.folder
  CARPETA`, `text open.cmd ORDEN` y `emit open_named` (con `pleamar --say
  bitacora-PID`) abren una pestaña para un agente con nombre, detrás de la de
  delante (`fact open.front true`: delante); pedida otra vez, se trae su
  pestaña. Un shell puede tener un equipo de agentes en una ventana, uno por
  pestaña.
- **Su pestaña, desde fuera.** Cada ventana atiende a `pleamar --say
  bitacora-PID`, y `emit show_layer N` pone delante la pestaña cuyo shell es la
  capa `N` de pleamar-wm.
- **Los agentes la leen.** Sus shells pasan por la capa de terminales de
  pleamar-wm, así que `pleamar-wm agent` los lee y ejecuta órdenes en ellos como
  en cualquier terminal.

# Teclas

| | |
|---|---|
| Ctrl+Mayús+T | una pestaña nueva, en la carpeta de la que estás |
| Ctrl+Mayús+W | cerrar el panel (y la pestaña, con el último) |
| Ctrl+Mayús+D / E | un panel al lado / debajo |
| Alt+flechas | al panel de ese lado |
| Ctrl+Tab, Ctrl+Mayús+Tab, Ctrl+AvPág/RePág | la pestaña siguiente, la anterior |
| Ctrl+Mayús+C / V | copiar lo seleccionado / pegar |
| Mayús+RePág / AvPág | por el historial |
| Ctrl++ / Ctrl+- / Ctrl+= | más grande, más pequeña, como estaba |
| Ctrl+Mayús+N | una ventana nueva |
| Ctrl+Mayús+F | buscar en su historial: Intro, la anterior; las flechas, arriba y abajo; Esc, listo |
| Ctrl+Mayús+A | un agente al lado, cableado al panel en el que estás |

El botón derecho abre un menú con lo mismo, y con *Seleccionar todo*, *Enviar
a…* y *Olvidar su historial*.

# Instalar

Hace falta Rust (estable) y una sesión de Wayland; pleamar viene con ella, como
dependencia que trae Cargo.

```sh
git clone https://github.com/k4ditano/bitacora && cd bitacora
sh install.sh      # ~/.local/bin/bitacora, su entrada entre las aplicaciones y su icono
```

`bitacora [CARPETA]` abre una ventana allí (donde estés, si no se dice);
`bitacora -e ORDEN …` ejecuta eso en vez de un shell, y se cierra con ello. Cada
ventana es su propio proceso: instalar una Bitácora nueva deja las abiertas con
sus shells.

Pon una tecla en tu compositor: en Hyprland, `bind = SUPER, Return, exec,
bitacora`; en pleamar-wm, `bind Super+Return launch bitacora` en `keys.conf`.

### Trabajar en su aspecto

`BITACORA_UI_DIR=ui bitacora` lee la ventana del repositorio en vez de la copia
del binario, y la recarga al guardar `bitacora.plm` o `bitacora.luau`: es una
escena de pleamar como cualquier otra.

# Agradecimientos

**[Alacritty]** - *Por `alacritty_terminal`, el emulador de debajo*

**[pleamar]** - *Por el elemento `terminal` y todo lo de alrededor*

# Licencia

Bitácora está bajo la [licencia MIT](LICENSE). Sus fuentes son JetBrains Mono,
Manrope y Newsreader, cada una bajo la SIL Open Font License (en `ui/fonts`).

[Read in English](README.md)

Hecho por **[@k4ditano](https://x.com/k4ditano)** — pasa a saludar, preguntar o
enseñar lo que has hecho en **[Discord]**. Si te hace el escritorio más bonito,
puedes **[invitarme a un café en Ko-fi](https://ko-fi.com/k4ditano)** ☕

[pleamar]: https://github.com/k4ditano/pleamar
[pleamar-wm]: https://github.com/k4ditano/pleamar-wm
[Alacritty]: https://github.com/alacritty/alacritty
[Discord]: https://discord.gg/N7kbYC49b2
