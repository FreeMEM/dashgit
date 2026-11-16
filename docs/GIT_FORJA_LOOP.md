# dashgit para Forja: bitácora

El empujón a git de `docs/IDE_ANALISIS.md` de Forja (sección 5 y fase 3 del plan). Rama `salidas`. La parte de Forja
está en su rama `git-panel` (`docs/GIT_LOOP.md` de Forja). Forja llama a dashgit como proceso aparte: Forja es MIT y
dashgit GPLv2, así que no importa sus módulos.

## Salidas para máquinas

Lo que Forja lee, con el formato de git (salvo `--rangos`, que git no tiene):

| Orden | Qué da |
|---|---|
| `status --porcelain -b` | `## rama` (o `## No commits yet on rama`, `## HEAD (no branch)`, `## rama...origin/rama`) y una línea por fichero con las dos letras de git (`XY ruta`): índice y disco en la misma línea (`MM`, `AM`), por orden de ruta, y los `??` al final. Antes salían dos líneas para un fichero con cambios en los dos sitios |
| `branch --show-current` | el nombre de la rama (nada con HEAD suelto). `branch` ya marcaba la actual con `*` |
| `diff [--cached] [commit [commit]]` | sin commits, el índice contra el disco; `--cached`, HEAD (o el commit) contra el índice; un commit, ese commit contra el disco (`diff HEAD`); dos, o `a..b`, uno contra otro |
| `diff --name-status`, `--name-only`, `--numstat`, `-U n` | como en git |
| `diff --rangos HEAD fichero` | para el margen del editor: `F ruta` y una línea por trozo, `A n c` (c líneas añadidas desde la n del fichero nuevo), `C n c` (cambiadas), `B n c` (c líneas quitadas justo antes de la n). Un trozo con q quitadas y p puestas da min(q, p) cambiadas y el resto añadidas o quitadas. Binario: `X` |
| `log --format=...` | `%H %h %T %t %P %p %an %ae %ad %ai %as %at %cn %ce %cd %ci %cs %ct %s %b %B %n %% %xNN`; también `--pretty=format:`, `--pretty=oneline`. `%ad` y `%cd` salen como `%ai` |
| `log [desde] [--] ruta...` | los commits que cambian esas rutas (ficheros o cajones), con la simplificación de git en las fusiones |
| `show [commit]` | el commit como log y su diff frente al primer padre (una fusión, sin diff); admite las opciones de formato y de diff, y `-s` |
| `show commit:ruta` | el contenido del fichero en ese commit (ruta desde la raíz) |
| `HEAD~2`, `main^`, `HEAD^2` | en log, show, diff, branch y reset |

Y para el panel de Cambios de Forja (quitar del índice):

- `reset [--soft | --mixed] [commit] [--] [ruta...]`: con rutas, las devuelve en el índice a como están en HEAD (o en
  el commit) sin tocar el disco; lo que no está en HEAD sale del índice. Sin rutas, todo el índice; con un commit,
  además mueve la rama (`--soft`: solo la rama). `--hard` aún no: lo dice y no hace nada.
- `restore --staged ruta` (= reset de esa ruta) y `restore ruta` (= `checkout -- ruta`).

Prueba: `tests/salidas.sh [DASH_DIR]` (FS-UAE con `DASH_KICKSTART`). Hace los mismos pasos en el Amiga y con el git
del PC y compara: status (limpio, con MM, AM, D, ??), branch, diff con las cuatro salidas, `-U0`, `--rangos`
(sacado de los `@@` de `git diff -U0`), `diff HEAD`, y sobre el repositorio del Amiga: `log --format` con todos los
campos, `log -- fichero`, `log -- cajón`, `show` (formato, cambios, `commit:ruta`), diff entre commits, reset y restore.

Y para cambiar de rama con cambios a medias y rehacer el último commit:

- `commit --amend [-m mensaje]`: rehace el commit de HEAD con lo que hay en el índice, con sus mismos padres y su
  autor (el committer es el de ahora); sin `-m`, con su mensaje.
- `stash [push [-m mensaje]] | list | apply | pop | drop [stash@{n}]`, como el de git: `refs/stash` apunta a un commit
  W (los ficheros seguidos tal como están en el disco) con dos padres, HEAD y un commit I con el índice; la lista va
  en `logs/refs/stash`. El git del PC la lee (`git stash list`, `git stash show`). `apply` sobre otro commit hace una
  fusión de tres vías; si choca con algo, no aplica nada y lo dice. Como en git, lo aplicado queda sin preparar (lo
  nuevo, añadido). Lo que no se sigue no se guarda (git tampoco, sin `-u`).

Prueba: `tests/stash.sh [DASH_DIR]`: push con un cambio sin preparar y otro preparado, list, pop, commit --amend (dos
veces: con y sin -m), apply sobre otro commit; el git del PC comprueba la lista, W, I, la historia y `git fsck`.

## Servidor (rama `servidor`)

Para que Forja ponga las marcas del margen mientras se escribe, sin pagar cada vez el arranque de dashgit.

    dashgit servidor [NOMBRE] [--dueno PUERTO]

- Abre el puerto ARexx `NOMBRE` (`DASHGIT` por defecto; en mayúsculas). Antes vigila el fichero de pedidos: el puerto
  sale lo último, así que quien espera al puerto para mandar su primer pedido no lo pierde. Va a prioridad -1.
- **ARexx** (síncrono, para scripts): la orden es una línea de dashgit como en el Shell (`-C "Work:x" status
  --porcelain -b`) y, tras un salto de línea, un cuerpo opcional. RC el de la orden; con 0, RESULT lo que escribe.
  Órdenes propias: `ADIOS`, `VERSION`, `MEMORIA` (memoria libre).
- **Ficheros** (no deja esperando a nadie): el cliente escribe `ENV:dashgit/NOMBRE.pedido` con `n` (un número) en la
  primera línea, la orden en la segunda y el cuerpo en las siguientes. La respuesta, en `ENV:dashgit/NOMBRE.respuesta`:
  `n rc ms` (ms: lo que tardó dentro), lo que escribe la orden (con un salto de línea al final) y `FIN n` en la
  última. Solo vale si la última línea es `FIN n`. Un pedido con el mismo `n` que el anterior no se repite.
- Acaba con `ADIOS`, Ctrl-C o, con `--dueno`, cuando ese puerto ya no está (se mira cada 2 s).
- Dentro no van `clone`, `fetch`, `pull`, `push` ni `servidor` (RC 10).
- Cada pedido empieza como uno nuevo: el cajón del servidor (`-C` vale solo para ese pedido), las opciones de diff y
  log, las reglas de ignorar. Los packs se vuelven a leer si cambia el repositorio o el número de packs.

`diff --rangos [commit] --texto FICHERO -- ruta`: los rangos de esa ruta en el commit (HEAD si no se dice; sin
commits, vacío) frente al texto de FICHERO; en el servidor, `--texto -` es el cuerpo del pedido. Un fichero que no
está en el commit sale todo añadido. El servidor guarda las líneas de los últimos 6 blobs y qué blob es cada (commit,
ruta). El texto no se parte en una lista: se queda en su búfer y se compara con `buffer_equals`.

El diff (todos, no solo el del servidor) pasa a ser el de Myers: cuesta las líneas por el número de diferencias, en
vez de las líneas al cuadrado. Si hay más de 400 diferencias en lo que cambia (200 en `--texto`), la tabla del LCS de
antes (si cabe) o todo quitado y todo puesto.

Para que la salida se pueda recoger, los `Print` pasan por `sal()` (util.dash), que escribe en la consola o, en el
servidor, en un texto.

Prueba: `tests/servidor.sh [DASH_DIR]` (`tests/cliente.dash` hace de cliente): por los dos canales, status, branch,
diff, diff --rangos, log --format, diff --cached, add y reset iguales que en el Shell; `--texto` (cambiado, sin salto
de línea al final, fichero nuevo, repositorio sin commits, 500 líneas) igual que lo que sale del `diff -U0` del PC;
push y un cajón que no existe dan RC 10; ADIOS; sin su dueño acaba; dos con el mismo nombre; el caso de Forja (cliente
a prioridad -1, nombre con punto, `-C` entre comillas, el primer pedido en cuanto sale el puerto, ADIOS y Ctrl-C); y
la memoria libre tras 200 y 400 pedidos.

## Bitácora

- 2026-11-16: todo lo de arriba. `tests/salidas.sh`: TODO BIEN en el A1200 emulado (3.1). Las demás pruebas siguen
  bien (fase1, fase2, diff, fase3, fusion, raros, arreglos). `arreglos.sh` esperaba el status corto de antes (dos
  líneas para un fichero, sin ordenar): ahora es el de git. `fase1.sh` buscaba "dashgit 0.1" en el uso: ahora 0.2.
- Fallo de Dash encontrado: `lista.sort(fn(a, b) -> a < b)` con una lista de textos no ordena (la deja como
  estaba). Con una función con tipos (`texto_antes(a: String, b: String) -> Bool`, util.dash) sí. dashgit lo usaba
  en las ramas, en las rutas de una fusión y en `diff --cached`: cambiado en los tres sitios.

- 2026-11-16: `diff HEAD` sin commits: HEAD es el árbol vacío (Forja lo pide para un repositorio recién hecho).
  `add -- ruta` daba un aviso y código 10 por el `--` (Forja lo usa): arreglado, con su prueba en salidas.sh.
- 2026-11-16: `commit --amend` y `stash`. `tests/stash.sh`: TODO BIEN.
- Tiempos (desde Forja, repositorio de 4 ficheros, 68020 a velocidad de A1200 emulado): `status --porcelain -b`
  1,1 s y `diff --rangos` 0,8 s, casi todo arrancar dashgit (390 KB). Ver la bitácora de Forja.
- 2026-11-16: todas las pruebas sin red, otra vez tras amend y stash: fase1, fase2, diff, fase3, fusion, raros,
  arreglos, salidas y stash, TODO BIEN. `tests/fase4.sh` (red) no se ha vuelto a pasar: el cerrojo de red lo tenían
  otras sesiones. Lo de red no se tocó, salvo el orden de las ramas (texto_antes) y `rev_commit` en `branch`.

- 2026-11-17, rama `servidor`: el servidor, `--texto`, Myers y `sal()`. Tiempos y pruebas: ver abajo.
  - Primer intento: Forja no recibía respuesta a su primer pedido. El servidor abría el puerto antes de borrar el
    pedido viejo y vigilar el fichero, y borraba el pedido que el cliente ya había escrito. Arreglado (el puerto, lo
    último) y con su caso en la prueba.
  - `operaciones` con la tabla del LCS tardaba 11 s con un fichero de 500 líneas y tres cambios separados (390 x 390
    celdas). Con Myers, 0,45 s dentro del servidor.
  - Medido en el A1200 emulado con OS 3.1 (`tests/servidor.sh`; repositorio de 5 ficheros, uno de 500 líneas; media
    de 10, del pedido a la respuesta, contando el ir y venir de los ficheros), con `REAL=1` (68020 a velocidad de
    A1200) y, entre paréntesis, con la configuración de siempre del emulador:

    | Pedido | Servidor | Dentro del servidor | dashgit aparte (Shell) |
    |---|---|---|---|
    | `status --porcelain -b` | 256 ms (337) | 237 ms (305) | 468 ms (565) |
    | `diff --rangos HEAD -- grande.txt` (sin cambios) | 247 ms (325) | 214 ms (289) | 450 ms (546) |
    | `diff --rangos --texto -` (500 líneas, 3 cambios) | 668 ms (789) | 380 ms (454) | |

    Lo que queda del status es trabajo de verdad (leer el índice y mirar los ficheros); del `--texto`, unos 300 ms
    son escribir y leer los 35 KB del texto por ENV: y partirlo. Desde Forja, dashgit aparte costaba 1,1 s.
  - Memoria: 8 KB menos de libre cada 200 pedidos (unos 40 bytes por pedido), igual en las dos tandas: no crece con
    el tamaño de lo pedido. No lo he buscado más.
  - Pruebas: servidor, salidas, stash, fase1, fase2, diff, fase3, fusion, raros y arreglos, TODO BIEN. fusion falló
    una vez por tiempo (tres emuladores a la vez y otras sesiones con los suyos) y pasó al repetirla sola. fase4 (red)
    no se ha pasado: no he cogido el cerrojo de red.

- 2026-11-17, con la extensión Git de Forja (rama `git-ext` de Forja): el servidor se quedaba sin contestar un
  pedido al azar (seguía vivo: contestaba por ARexx). Era una carrera: si el cliente estaba leyendo la respuesta de
  antes justo cuando el servidor escribía la nueva, el fichero no se dejaba escribir y la respuesta se perdía; el
  servidor ya daba ese pedido por hecho y no lo repetía. Ahora la respuesta se reintenta (hasta 1 s), el mismo número
  otra vez vuelve a escribir su respuesta sin repetir la orden (el cliente reescribe su pedido si en 1,5 s no ve
  respuesta), y un pedido leído a medias se vuelve a leer en la siguiente vuelta sin esperar otro aviso. Con eso,
  `tests/git_panel.sh` de Forja pasa con el servidor todo el rato (A1200, REAL=1 y coffin).

## Falta

- `status -b` no dice cuántos commits va por delante o por detrás del remoto (`[ahead 1]`).
- `reset --hard`, `stash -u` (lo no seguido), `stash show`, `tag`, `remote`.
- `show` de una fusión no enseña el diff combinado de git.
- Servidor: un pedido largo (un `status` de un repositorio grande) no deja atender otro hasta que acaba; y si un
  pedido se colgara, el servidor no contesta más (la extensión de Forja lo da por perdido a los 20 s y sigue con
  dashgit aparte). Pierde unos 40 bytes por pedido.
- Lo que falta en Dash para el servidor: `cx_wait` no despierta con el puerto ARexx (`rexx_signal`), así que el
  servidor mira el puerto cada 200 ms (el canal de ficheros sí despierta enseguida). Meter un elemento en una lista
  cuesta mucho en un 68020: medido en el A1200 emulado, `push` de un texto 160 µs y de un número 40 µs (un
  `buffer_set_long` 9 µs); `str_split` de 500 líneas, 290 ms. Por eso `--texto` no parte el texto en una lista.
