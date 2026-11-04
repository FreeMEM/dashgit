# dashgit

Un cliente de git para AmigaOS 3.x en 68k, escrito en [Dash](https://github.com/FreeMEM/dash). Usa el mismo formato
que git: un repositorio hecho en el Amiga se abre con git en el PC, y al revés.

Hace `clone`, `fetch`, `pull` (solo avance rápido) y `push` por http y https (con AmiSSL), y en local `init`, `add`, `rm`, `status`, `commit`, `log`, `branch`, `checkout`, `diff`, `config`, `hash-object` y `cat-file`. Aún no sabe fusionar ramas. El plan, por fases, está en
[docs/DISENO.md](docs/DISENO.md).

## Compilar

Necesita un Dash posterior a la 2.2.0, con el PR #108 (SHA-1, adler32, `inflate_used`...).

    ~/Projects/FreeMEMLang/dash src/main.dash -o build/dashgit

## Pruebas

En FS-UAE, con `DASH_KICKSTART` apuntando a una ROM de Kickstart 3.1:

    tests/fase1.sh [cajón de Dash]
    tests/fase2.sh [cajón de Dash]
    tests/diff.sh [cajón de Dash]
    tests/fase3.sh [cajón de Dash]
    tests/fase4.sh [cajón de Dash]     # red, contra un servidor git en el PC

## Licencia

GPLv2, la misma de git. Ver [LICENSE](LICENSE).
