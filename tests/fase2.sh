#!/bin/bash
# Fase 2 de dashgit en FS-UAE: add, status, commit, log, branch, checkout y rm. Después el git del PC comprueba el
# repositorio que hizo el Amiga. Acaba con "TODO BIEN" si todo fue bien.
#
#   DASH_KICKSTART=... tests/fase2.sh [DASH_DIR]
set -e
dash=${1:-$HOME/Projects/FreeMEMLang}
aqui=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cp -r "$HOME/.cache/dash-emu/sys31" "$tmp/sys"
chmod -R u+w "$tmp/sys"
mkdir -p "$tmp/sys/S" "$tmp/sys/P/sub"
"$dash/dash" "$aqui/src/main.dash" -o "$tmp/sys/C/dashgit"
printf 'hola\n' > "$tmp/sys/P/a.txt"
printf 'dentro\n' > "$tmp/sys/P/sub/b.txt"
printf 'ruido\n' > "$tmp/sys/P/traza.log"
printf '*.log\n' > "$tmp/sys/P/.gitignore"
n=0
r() { n=$((n+1)); printf 'dashgit %s >DH0:R/%02d.txt\n' "$1" $n; }
{
  echo "MakeDir DH0:R"
  echo "CD DH0:P"
  echo "dashgit init >NIL:"
  r "config user.name Amiguero"
  r "config user.email amiguero@amiga.org"
  r "add ."                                   # 03
  r "status -s"                               # 04
  r "commit -m primero"                       # 05
  r "status"                                  # 06
  echo "Echo \"adios amigo\" >a.txt"
  r "status -s"                               # 07
  r "commit -am segundo"                      # 08
  r "log --oneline"                           # 09
  r "branch otra"                             # 10
  r "checkout otra"                           # 11
  echo "Echo \"nuevo\" >c.txt"
  r "add c.txt"                               # 12
  r "commit -m tercero"                       # 13
  r "checkout main"                           # 14
  n=$((n+1)); echo "List >DH0:R/15.txt c.txt"
  r "branch"                                  # 16
  r "log"                                     # 17
  r "rm sub/b.txt"                            # 18
  r "status -s"                               # 19
  r "commit -m cuarto"                        # 20
  r "status -s"                               # 21
} >> "$tmp/sys/S/Startup-Extra"
cd "$dash" && python3 tools/emu_run.py --timeout ${TIEMPO:-400} --system "$tmp/sys" --keep "$tmp/disco" "$tmp/sys/C/dashgit" >/dev/null 2>&1 || true
d="$tmp/disco"
fallos=0
ver() { iconv -f latin1 -t utf-8 "$d/R/$1.txt" 2>/dev/null; }
mira() { # nombre fichero esperado
  if [ "$(ver $2)" = "$3" ]; then echo "bien $1"; else echo "FALLO $1:"; ver $2 | head -8; fallos=$((fallos+1)); fi
}
contiene() { # nombre fichero texto
  if ver $2 | grep -q -- "$3"; then echo "bien $1"; else echo "FALLO $1:"; ver $2 | head -8; fallos=$((fallos+1)); fi
}
mira "add y status -s" 04 "$(printf 'A  .gitignore\nA  a.txt\nA  sub/b.txt')"
contiene "primer commit" 05 "(primer commit)"
contiene "status limpio" 06 "está limpio"
mira "cambio sin añadir" 07 " M a.txt"
contiene "commit -a" 08 "segundo"
[ "$(ver 09 | wc -l)" = 2 ] && echo "bien log" || { echo "FALLO log:"; ver 09; fallos=$((fallos+1)); }
contiene "checkout otra" 11 "Cambiado a la rama otra"
contiene "tercero" 13 "tercero"
contiene "checkout main" 14 "Cambiado a la rama main"
if ver 15 | grep -q "c.txt"; then echo "FALLO c.txt sigue en main"; fallos=$((fallos+1)); else echo "bien c.txt fuera en main"; fi
mira "branch" 16 "$(printf '* main\n  otra')"
contiene "log largo" 17 "Autor: Amiguero <amiguero@amiga.org>"
mira "rm" 19 "D  sub/b.txt"
mira "limpio al final" 21 ""
[ ! -e "$d/P/c.txt" ] && echo "bien c.txt no está en el disco" || { echo "FALLO c.txt está en el disco"; fallos=$((fallos+1)); }
# el git del PC
cd "$d/P"
find . -name "*.uaem" -delete
git fsck --strict 2>&1 | grep -iv "dangling\|colgando\|notice\|Checking\|Revisando" | head -5 || true
[ "$(git log --format=%s main | tr '\n' ' ')" = "cuarto segundo primero " ] && echo "bien git log main" || { echo "FALLO git log main: $(git log --format=%s main | tr '\n' ' ')"; fallos=$((fallos+1)); }
[ "$(git log --format=%s otra | tr '\n' ' ')" = "tercero segundo primero " ] && echo "bien git log otra" || { echo "FALLO git log otra"; fallos=$((fallos+1)); }
[ "$(git log -1 --format='%an <%ae>')" = "Amiguero <amiguero@amiga.org>" ] && echo "bien autor" || { echo "FALLO autor"; fallos=$((fallos+1)); }
[ "$(git status --porcelain)" = "?? traza.log" ] || [ -z "$(git status --porcelain)" ] && echo "bien git status" || { echo "FALLO git status:"; git status --porcelain; fallos=$((fallos+1)); }
[ "$(git write-tree)" = "$(git rev-parse 'HEAD^{tree}')" ] && echo "bien índice igual que HEAD" || { echo "FALLO índice"; fallos=$((fallos+1)); }
[ "$(git show main~1:a.txt)" = "adios amigo" ] && echo "bien contenido" || { echo "FALLO contenido: $(git show main~1:a.txt)"; fallos=$((fallos+1)); }
[ $fallos -eq 0 ] && echo "TODO BIEN"
exit 0
