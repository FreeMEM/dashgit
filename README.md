# dashgit

Un cliente de git para AmigaOS 3.x en 68k, escrito en [Dash](https://github.com/FreeMEM/dash). Usa el mismo formato
que git: un repositorio hecho en el Amiga se abre con git en el PC, y al revés.

**Está en alfa.** Las pruebas pasan en el emulador y se comparan con el git del PC, pero aún hay mucho que probar,
sobre todo en Amigas de verdad y con repositorios grandes. Ten copia de lo importante antes de usarlo con ello.

Hace `clone`, `fetch`, `pull` y `push` por http y https (con AmiSSL), y en local `init`, `add`, `rm`, `status`, `commit`, `log`, `branch`, `checkout`, `diff`, `merge` (con conflictos, como git), `merge-base`, `check-ignore`, `config`, `hash-object` y `cat-file`. El plan, por fases, está en
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
    tests/fase4.sh [cajón de Dash]     # red, contra un servidor git en el PC

## Licencia

GPLv2, la misma de git. Ver [LICENSE](LICENSE).
