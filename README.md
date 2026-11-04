# dashgit

Un cliente de git para AmigaOS 3.x en 68k, escrito en [Dash](https://github.com/FreeMEM/dash). Usa el mismo formato
que git: un repositorio hecho en el Amiga se abre con git en el PC, y al revés.

Está empezando. Hoy hace `init`, `hash-object`, `cat-file` y `config`. El plan, por fases, está en
[docs/DISENO.md](docs/DISENO.md).

## Compilar

    ~/Projects/FreeMEMLang/dash src/main.dash -o build/dashgit

## Pruebas

En FS-UAE, con `DASH_KICKSTART` apuntando a una ROM de Kickstart 3.1:

    tests/fase1.sh [cajón de Dash]

## Licencia

GPLv2, la misma de git. Ver [LICENSE](LICENSE).
