#!/bin/bash
# Fase 4 de dashgit en FS-UAE: clone, commit, push, fetch y pull contra un servidor git por HTTP en el PC
# (tests/servidor_git.py, git http-backend). Acaba con "TODO BIEN".
#
#   DASH_KICKSTART=... tests/fase4.sh [DASH_DIR]       (chunked=1: el servidor contesta en trozos)
set -e
dash=${1:-$HOME/Projects/FreeMEMLang}
aqui=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
puerto=$((20000 + RANDOM % 20000))
trap 'kill $srv 2>/dev/null; rm -rf "$tmp"' EXIT
cp -r "$HOME/.cache/dash-emu/sys31" "$tmp/sys"
chmod -R u+w "$tmp/sys"
mkdir -p "$tmp/sys/S" "$tmp/srv" "$tmp/obra"
"$dash/dash" "$aqui/src/main.dash" -o "$tmp/sys/C/dashgit"
(
  cd "$tmp/obra"
  git init -q -b main
  git config user.name PC; git config user.email pc@pc
  mkdir -p src
  for v in 1 2 3 4; do
    python3 -c "
import sys
v=int(sys.argv[1])
open('src/largo.txt','w').write(''.join('linea %d version %d\n' % (i, v if i % 5 == 0 else 0) for i in range(300)))
" $v
    echo "v$v" > version.txt
    git add -A; git commit -qm "versión $v"
  done
  git tag v1.0
  git checkout -qb otra; echo "en otra" > otra.txt; git add -A; git commit -qm "en otra"; git checkout -q main
  git clone -q --bare . "$tmp/srv/origen.git"
)
(cd "$tmp/srv/origen.git" && git config http.receivepack true && git repack -adq -f --depth=10)
python3 "$aqui/tests/servidor_git.py" "$tmp/srv" $puerto &
srv=$!
sleep 1
url="http://127.0.0.1:$puerto/origen.git"
n=0
r() { n=$((n+1)); printf 'dashgit %s >DH0:R/%02d.txt\n' "$1" $n; }
{
  echo "MakeDir DH0:R"
  echo "CD DH0:"
  echo "SetEnv DASHGIT_TOKEN nada"
  r "clone $url A"                      # 01
  echo "CD DH0:A"
  r "log --oneline"                     # 02
  r "status -s"                         # 03
  r "branch"                            # 04
  r "config user.name Amiga"            # 05
  r "config user.email a@a"             # 06
  echo "Echo \"desde el Amiga\" >amiga.txt"
  r "add amiga.txt"                     # 07
  r "commit -m del-amiga"               # 08
  r "push"                              # 09
  r "push"                              # 10  (ya al día)
  echo "CD DH0:"
  r "clone $url B"                      # 11
  echo "CD DH0:A"
  echo "Echo \"otra vez\" >>amiga.txt"
  r "commit -am segundo-del-amiga"      # 12
  r "push origin main"                  # 13
  echo "CD DH0:B"
  r "pull"                              # 14
  r "log --oneline -n 2"                # 15
  r "fetch"                             # 16 (nada nuevo)
} >> "$tmp/sys/S/Startup-Extra"
cd "$dash" && python3 tools/emu_run.py --timeout ${TIEMPO:-600} --set bsdsocket_library=1 --system "$tmp/sys" --keep "$tmp/disco" "$tmp/sys/C/dashgit" >/dev/null 2>&1 || true
d="$tmp/disco"
find "$d" -name "*.uaem" -delete
fallos=0
ver() { iconv -f latin1 -t utf-8 "$d/R/$1.txt" 2>/dev/null; }
bien() { echo "bien $1"; }
mal() { echo "FALLO $1"; fallos=$((fallos+1)); }
contiene() { if ver $2 | grep -q -- "$3"; then bien "$1"; else mal "$1:"; ver $2 | head -6; fi; }
contiene "clone" 01 "Hecho: rama main"
o=$(git -C "$tmp/obra" log --oneline main)
[ "$(ver 02)" = "$o" ] && bien "log del clon" || { mal "log del clon:"; ver 02 | head -3; }
[ -z "$(ver 03)" ] && bien "status limpio" || { mal "status:"; ver 03; }
[ "$(ver 04)" = "* main" ] && bien "branch" || { mal "branch:"; ver 04; }
contiene "push" 09 "main -> main"
contiene "push al día" 10 "al día"
contiene "segundo push" 13 "main -> main"
contiene "pull" 14 "Avance rápido"
contiene "log tras pull" 15 "segundo-del-amiga"
[ "$(git -C "$tmp/srv/origen.git" log --format=%s -1 main)" = "segundo-del-amiga" ] && bien "el servidor tiene los commits" || mal "el servidor no tiene los commits"
git -C "$tmp/srv/origen.git" fsck --strict 2>&1 | grep -iv "dangling\|colgando\|notice\|Checking\|Revisando\|actualizando" | head -5 || true
for c in A B; do
  (cd "$d/$c" && git fsck --strict 2>&1 | grep -iv "dangling\|colgando\|notice\|Checking\|Revisando\|actualizando" | head -3) || true
  [ -z "$(cd "$d/$c" && git status --porcelain)" ] && bien "git status limpio en $c" || { mal "git status en $c:"; (cd "$d/$c" && git status --porcelain | head -3); }
done
[ "$(cat "$d/B/amiga.txt")" = "$(printf 'desde el Amiga\notra vez')" ] && bien "fichero tras pull" || { mal "fichero tras pull:"; cat "$d/B/amiga.txt"; }
[ "$(git -C "$d/A" rev-parse v1.0)" = "$(git -C "$tmp/obra" rev-parse v1.0)" ] && bien "etiqueta" || mal "etiqueta"
echo "-- peticiones:"; cat "$tmp/srv/peticiones.txt" | cut -c1-110
[ $fallos -eq 0 ] && echo "TODO BIEN"
exit 0
