# Bitácora

**La terminal del escritorio de pleamar.** Pestañas con un glifo propio,
paneles al lado o debajo, los colores del escritorio, y una línea que dice
dónde estás y en qué rama.

![Bitácora: dos paneles, el menú del botón derecho y la línea de abajo](docs/bitacora.png)

La terminal en sí no está aquí: es el elemento `terminal` de
[pleamar](https://github.com/k4ditano/pleamar), un shell en su propia pty que
el motor pinta con sus propias letras (por debajo, el emulador de Alacritty y
Zed, `alacritty_terminal`). Bitácora es su ventana: una escena de pleamar
(`ui/bitacora.plm`) y su lógica (`ui/bitacora.luau`), metidas en un solo
binario con sus fuentes.

[Read in English](README.md)

## Qué hace

- **Pestañas** (seis como mucho), con el nombre de lo que corre en ellas o de su
  carpeta, y un glifo de cinco por cinco granos hecho con esa carpeta: la misma
  carpeta, el mismo glifo, la veas donde la veas.
- **Paneles** (cuatro por pestaña): al lado o debajo; el que tiene el teclado,
  con el borde en el acento del escritorio, y los demás un poco más tenues. Un
  shell que termina se lleva su panel; el último, la ventana.
- **Los colores del escritorio.** Con [Calima](https://github.com/k4ditano/calima)
  toma el acento, la superficie y la tinta del Taller, claro u oscuro, y los
  sigue cuando cambian; los dieciséis colores ANSI están afinados para cada uno.
- **La línea de abajo**: la carpeta del shell con el teclado, su rama de git, qué
  corre y cuántas columnas y líneas tiene.
- **Lo que hace una buena terminal**: colores de 16, 256 y 24 bits, negrita,
  cursiva y subrayados; las líneas de cajas y los bloques dibujados a mano para
  que encajen; seleccionar con el ratón (doble clic, una palabra; triple, la
  línea), Ctrl+Mayús+C y V, el botón central pega; la rueda por el historial;
  Ctrl+clic abre un enlace; los programas que quieren el ratón (vim, htop) lo
  tienen; y el cursor se desliza al escribir.
- **Los agentes la leen.** En una sesión de pleamar-wm sus shells pasan por la
  capa de terminales, así que `pleamar-wm agent` los lee y ejecuta órdenes en
  ellos como en cualquier otra terminal.

## Con agentes

En una sesión de pleamar-wm, Bitácora le pregunta cada segundo por sus shells
(`pleamar-wm term list --json`) y enseña lo que sabe:

- **Una pestaña con un agente** (Claude Code, Codex…) se llama como su tarea, y
  un punto dice cómo está: respira mientras trabaja, ámbar si te pregunta algo.
  Uno que acaba en una pestaña de atrás le deja un punto, como una campana; la
  línea de abajo dice «Claude · trabajando».
- **La pestaña de un compañero.** Abierta para uno de los compañeros de la
  caravana (los de [Calima](https://github.com/k4ditano/calima), `pleamar-wm
  link open --name`), su primera pestaña —y ninguna otra— es ese compañero: su
  nombre, su glifo y su color, de su ficha.
- **Un agente al lado** (Ctrl+Mayús+A): un panel al lado del tuyo con Claude
  (`BITACORA_AGENT` dice otro), y un cable entre los dos (`pleamar-wm term
  pair`), dibujado como un nudo de granos que lleva una ola mientras algo va por
  él. Para ese agente tu panel es una ventana más con cable a la suya: lo lee y
  ejecuta cosas en él con sus herramientas de `link`.
- **Enviar a…** (botón derecho): lo seleccionado, como carta a un compañero
  (`pleamar-wm link post`).
- **Toda una caravana en una ventana.** `text open.name ID`, `text open.folder
  CARPETA`, `text open.cmd ORDEN` y `emit open_named` (por `pleamar --say
  bitacora-PID`) abren una pestaña para ese compañero, con su nombre en su
  shell, detrás de la que está delante (`fact open.front true`: delante); si se
  pide otra vez, su pestaña se pone delante. Calima mete ahí toda su caravana,
  un compañero por pestaña (diez pestañas y doce shells como mucho).
- **Su pestaña, desde fuera.** Cada ventana atiende a `pleamar --say
  bitacora-PID`, y `emit show_layer N` pone delante la pestaña cuyo shell es la
  capa `N` de pleamar-wm: la isla de Calima te lleva a la pestaña misma de un
  agente.

## Teclas

| | |
|---|---|
| Ctrl+Mayús+T | una pestaña nueva, en la carpeta de la que estás |
| Ctrl+Mayús+W | cerrar el panel (y la pestaña, con el último) |
| Ctrl+Mayús+D / E | un panel al lado / debajo |
| Alt+flechas | al panel de ese lado |
| Ctrl+Tab, Ctrl+Mayús+Tab, Ctrl+AvPág/RePág | la pestaña siguiente, la anterior |
| Ctrl+Mayús+C / V | copiar lo seleccionado / pegar |
| Mayús+RePág / AvPág | por el historial |
| Ctrl++ / Ctrl+- / Ctrl+= (Ctrl+Mayús+0 en un teclado español) | más grande, más pequeña, como estaba |
| Ctrl+Mayús+N | una ventana nueva |
| Ctrl+Mayús+F | buscar en su historial: Intro, la anterior; las flechas, arriba y abajo; Esc, terminar |
| Ctrl+Mayús+A | un agente al lado, con cable al panel en el que estás |

El botón derecho abre un menú con lo mismo, y con *Seleccionar todo*,
*Enviar a…* y *Olvidar su historial*.

## Instalar

Necesita Rust y un pleamar con el elemento `terminal` (la rama `terminal`
hasta que salga en una versión).

```sh
git clone https://github.com/k4ditano/bitacora && cd bitacora
sh install.sh      # ~/.local/bin/bitacora, su entrada en las aplicaciones y su icono
```

`bitacora [CARPETA]` abre una ventana ahí (donde estés, si no se dice);
`bitacora -e ORDEN …` ejecuta eso en vez de un shell, y se cierra con ello. Cada
ventana es su propio proceso: instalar una Bitácora nueva deja las abiertas
con sus shells.

## Trabajar en su aspecto

`BITACORA_UI_DIR=ui bitacora` lee la ventana del repositorio en vez de la copia
del binario, y la recarga al guardar `bitacora.plm` o `bitacora.luau`.

## Licencia

MIT. Sus fuentes son JetBrains Mono, Manrope y Newsreader, cada una con la SIL
Open Font License (en `ui/fonts`).
