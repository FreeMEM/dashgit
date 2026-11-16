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
- Tiempos (Forja, A1200 emulado a toda velocidad): `status --porcelain -b` y `diff --rangos` de un fichero de un
  repositorio de 4 ficheros, 1,1 s cada uno, casi todo arrancar dashgit (390 KB). Ver la bitácora de Forja.

## Falta

- `status -b` no dice cuántos commits va por delante o por detrás del remoto (`[ahead 1]`).
- `reset --hard`, `stash -u` (lo no seguido), `stash show`, `tag`, `remote`.
- `show` de una fusión no enseña el diff combinado de git.
