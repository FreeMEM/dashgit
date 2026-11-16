# dashgit

Un cliente de git para AmigaOS 3.x en 68k, escrito en [Dash](https://github.com/FreeMEM/dash). Usa el mismo formato
que git: un repositorio hecho en el Amiga se abre con git en el PC, y al revés.

**Está en alfa.** Las pruebas pasan en el emulador y se comparan con el git del PC, pero aún hay mucho que probar,
sobre todo en Amigas de verdad y con repositorios grandes. Ten copia de lo importante antes de usarlo con ello.

Hace `clone`, `fetch`, `pull` y `push` por http y https (con AmiSSL), y en local `init`, `add`, `rm`, `status`, `commit` (también `--amend`), `log` (también `--format` y `-- fichero`), `show`, `branch`, `checkout`, `diff` (también entre commits, `--name-status`, `--numstat` y `--rangos`), `reset`, `restore`, `stash`, `merge` (con conflictos, como git), `merge-base`, `check-ignore`, `config`, `hash-object` y `cat-file`. Las salidas para programas (`status --porcelain -b`, `diff --rangos`, `log --format`...) son las que usa Forja: [docs/GIT_FORJA_LOOP.md](docs/GIT_FORJA_LOOP.md). El plan, por fases, está en
[docs/DISENO.md](docs/DISENO.md).

## Credenciales (token de GitHub)

Para `push` (y para clonar un repositorio privado) GitHub pide un token, no la contraseña. Se hace en GitHub, en
Settings > Developer settings > Personal access tokens: un token "fine-grained" con permiso "Contents: Read and
write" en el repositorio, o uno "classic" con "repo".

En el Amiga, con variables de entorno:

    SetEnv DASHGIT_USUARIO tu_usuario
    SetEnv DASHGIT_TOKEN ghp_xxxxxxxx
    SetEnv DASHGIT_HOST github.com

Para que duren tras reiniciar, cópialas a `ENVARC:` (`Copy ENV:DASHGIT#? ENVARC:`), o en OS 3.2 usa `SetEnv SAVE`.

`DASHGIT_HOST` es opcional, pero conviene: así el token solo va a ese servidor. O en el fichero
`ENVARC:dashgit/credenciales`, con el formato de netrc (un servidor por línea):

    machine github.com login tu_usuario password ghp_xxxxxxxx

El token solo se manda por https (hace falta AmiSSL); por http iría sin cifrar y no se manda nunca (salvo a
127.0.0.1, que no sale del ordenador).

## Servidor (para Forja y otros programas)

Arrancar dashgit cuesta casi un segundo en un A1200. `dashgit servidor` se queda abierto y contesta órdenes sin ese
coste:

    dashgit servidor [NOMBRE] [--dueno PUERTO]

- Abre el puerto ARexx `NOMBRE` (`DASHGIT` si no se dice). Cada orden es una línea como en el Shell, con `-C cajón`
  si hace falta: `ADDRESS DASHGIT '-C Work:juego status --porcelain -b'`. RC es el código de la orden y, con 0,
  RESULT es lo que escribe. `ADIOS` lo cierra.
- Para un programa que no quiere quedarse esperando (Forja), por ficheros: escribe en `ENV:dashgit/NOMBRE.pedido`
  un número en la primera línea, la orden en la segunda y, si hace falta, un texto en las siguientes. La respuesta
  llega a `ENV:dashgit/NOMBRE.respuesta`: `número rc ms` en la primera línea, lo que escribe la orden y `FIN número`
  en la última.
- Con `--dueno PUERTO`, se cierra solo cuando ese puerto ya no está.
- Dentro no van `clone`, `fetch`, `pull` ni `push`: esas, con dashgit aparte.

`diff --rangos [commit] --texto fichero -- ruta` da los rangos de `ruta` frente a ese texto (por ejemplo, lo que hay
en el editor sin guardar). En el servidor, `--texto -` es el texto que va tras la orden.

## Compilar

Necesita un Dash posterior a la 2.2.0, con el PR #108 (SHA-1, adler32, `inflate_used`...).

    ~/Projects/FreeMEMLang/dash src/main.dash -o build/dashgit

## Pruebas

En FS-UAE, con `DASH_KICKSTART` apuntando a una ROM de Kickstart 3.1:

    tests/fase1.sh [cajón de Dash]
    tests/fase2.sh [cajón de Dash]
    tests/diff.sh [cajón de Dash]
    tests/fase3.sh [cajón de Dash]
    tests/fusion.sh [cajón de Dash]
    tests/raros.sh [cajón de Dash]
    tests/arreglos.sh [cajón de Dash]
    tests/salidas.sh [cajón de Dash]
    tests/stash.sh [cajón de Dash]
    tests/servidor.sh [cajón de Dash]
    tests/fase4.sh [cajón de Dash]     # red, contra un servidor git en el PC

## Licencia

GPLv2, la misma de git. Ver [LICENSE](LICENSE).
