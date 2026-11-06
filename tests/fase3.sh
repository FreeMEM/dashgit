#!/bin/bash
# Fase 3 de dashgit en FS-UAE: un repositorio clonado en el PC (todo en un pack, con deltas) se usa en el Amiga:
# log, cat-file de objetos con delta, status, checkout de otra rama y un commit nuevo encima. Acaba con "TODO BIEN".
#
#   DASH_KICKSTART=... tests/fase3.sh [DASH_DIR]
set -e
dash=${1:-$HOME/Projects/FreeMEMLang}
aqui=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cp -r "$HOME/.cache/dash-emu/sys31" "$tmp/sys"
chmod -R u+w "$tmp/sys"
mkdir -p "$tmp/sys/S" "$tmp/origen"
"$dash/dash" "$aqui/src/main.dash" -o "$tmp/sys/C/dashgit"
# el repositorio de origen: varias versiones de los mismos ficheros, para que git haga deltas
(
  cd "$tmp/origen"
  git init -q -b main
  git config user.name PC; git config user.email pc@pc
  mkdir -p src docs
  for v in 1 2 3 4 5 6; do
    python3 -c "
import sys
v=int(sys.argv[1])
open('src/largo.txt','w').write(''.join('linea %d version %d\n' % (i, v if i % 7 == 0 else 0) for i in range(400)))
open('docs/notas.txt','w').write('notas\n' * (10 + v))
" $v
    echo "v$v" > version.txt
    git add -A; git commit -qm "versión $v"
  done
  git checkout -qb otra
  echo "solo en otra" > otra.txt; git add -A; git commit -qm "en otra"
  git checkout -q main
  git tag -a v2 -m "etiqueta anotada" main~2
)
git clone -q --no-local "$tmp/origen" "$tmp/sys/P"
(cd "$tmp/sys/P" && git branch -q otra origin/otra && git branch -q borrar origin/otra && git branch -q borrar2 main~1 && git gc -q --aggressive && git config user.name Amiga && git config user.email a@a)
# borrar y borrar2 quedan en packed-refs; borrar2 además suelta (con otro commit), para branch -d
(cd "$tmp/sys/P" && git update-ref refs/heads/borrar2 main~3 && grep -q " refs/heads/borrar$" .git/packed-refs && [ -f .git/refs/heads/borrar2 ])
ls "$tmp/sys/P/.git/objects/pack/"*.pack >/dev/null
# git deja los packs de solo lectura y FS-UAE no los abre así (abre en lectura y escritura); en un Amiga no pasa
chmod -R u+w "$tmp/sys/P"
# git deja los packs de solo lectura, y FS-UAE no los abre así (abre en lectura y escritura): en un Amiga no pasa
chmod -R u+w "$tmp/sys/P"
sueltos=$(find "$tmp/sys/P/.git/objects" -path '*/pack' -prune -o -type f -print | grep -v info | wc -l)
echo "objetos sueltos: $sueltos; con delta: $(cd "$tmp/sys/P" && git verify-pack -v .git/objects/pack/*.idx | awk 'NF==7' | wc -l)"
# blobs con delta, para cat-file
delta=$(cd "$tmp/sys/P" && git verify-pack -v .git/objects/pack/*.idx | awk 'NF==7 && $2=="blob" {print $1}' | head -4)
n=0
r() { n=$((n+1)); printf 'dashgit %s >DH0:R/%02d.txt\n' "$1" $n; }
{
  echo "MakeDir DH0:R"
  echo "CD DH0:P"
  echo "dashgit branch -d borrar >DH0:R/bd1.txt"
  echo "dashgit branch -d borrar2 >DH0:R/bd2.txt"
  echo "dashgit branch -d borrar >DH0:R/bd3.txt"
  r "log --oneline"                       # 01
  r "status -s"                           # 02
  i=0; for b in $delta; do r "cat-file -p $b"; done   # 03..
} >> "$tmp/sys/S/Startup-Extra"
ncat=$(echo $delta | wc -w)
base=$((2 + ncat))
{
  r "branch"
  r "checkout otra"
  r "log --oneline -n 2"
  echo "Echo \"del amiga\" >amiga.txt"
  r "add amiga.txt"
  r "commit -m desde-el-amiga"
  echo "dashgit log --oneline v2 >DH0:R/tag_log.txt"
  echo "dashgit branch de-tag v2 >DH0:R/tag_branch.txt"
  echo "dashgit checkout v2 >DH0:R/tag_checkout.txt"
  echo "dashgit status -s >DH0:R/tag_status.txt"
} >> "$tmp/sys/S/Startup-Extra"
cd "$dash" && python3 tools/emu_run.py --timeout ${TIEMPO:-400} --system "$tmp/sys" --keep "$tmp/disco" "$tmp/sys/C/dashgit" >/dev/null 2>&1 || true
d="$tmp/disco"
cd "$d/P"; find . -name "*.uaem" -delete
fallos=0
ver() { cat "$d/R/$1.txt" 2>/dev/null; }
bien() { echo "bien $1"; }
mal() { echo "FALLO $1"; fallos=$((fallos+1)); }
[ "$(ver 01 | iconv -f latin1 -t utf-8)" = "$(git log --oneline main)" ] && bien "log desde el pack" || { mal "log:"; ver 01 | head -3; git log --oneline main | head -3; }
[ -z "$(ver 02)" ] && bien "status limpio" || { mal "status:"; ver 02 | head -5; }
k=2; for b in $delta; do k=$((k+1)); kk=$(printf %02d $k)
  if cmp -s <(git cat-file -p $b) "$d/R/$kk.txt"; then bien "cat-file con delta $b"; else mal "cat-file $b ($(wc -c < "$d/R/$kk.txt") bytes)"; fi
done
k=$((k+1)); [ "$(ver $(printf %02d $k))" = "$(printf '  main\n* otra')" ] || [ "$(ver $(printf %02d $k))" = "$(printf '* main\n  otra')" ] && bien "branch" || { mal "branch:"; ver $(printf %02d $k); }
k=$((k+1)); grep -q "Cambiado a la rama otra" "$d/R/$(printf %02d $k).txt" && bien "checkout otra" || { mal "checkout:"; ver $(printf %02d $k); }
k=$((k+1))
k=$((k+1))
k=$((k+1)); grep -q "desde-el-amiga" "$d/R/$(printf %02d $k).txt" && bien "commit" || { mal "commit:"; ver $(printf %02d $k); }
[ "$(git show otra:otra.txt 2>/dev/null)" = "solo en otra" ] && bien "fichero de otra" || mal "fichero de otra"
[ "$(git log --format=%s -1 otra)" = "desde-el-amiga" ] && bien "git ve el commit" || mal "git ve el commit"
git fsck --strict 2>&1 | grep -iv "dangling\|colgando\|notice\|Checking\|Revisando\|actualizando" | head -5 || true
[ -z "$(git status --porcelain)" ] && bien "git status limpio" || { mal "git status:"; git status --porcelain | head; }
# branch -d de ramas en packed-refs (borrar2 también suelta)
grep -q "Rama borrar borrada" "$d/R/bd1.txt" && grep -q "Rama borrar2 borrada" "$d/R/bd2.txt" && bien "branch -d" || { mal "branch -d:"; cat "$d/R/bd1.txt" "$d/R/bd2.txt"; }
grep -q "no existe la rama borrar" "$d/R/bd3.txt" && bien "branch -d otra vez: no existe" || { mal "branch -d otra vez:"; cat "$d/R/bd3.txt"; }
[ -z "$(git branch --list 'borrar*')" ] && ! grep -q "refs/heads/borrar" .git/packed-refs && [ ! -e .git/refs/heads/borrar2 ] && git show-ref --verify -q refs/tags/v2 && bien "fuera de packed-refs y lo demás sigue" || { mal "packed-refs:"; cat .git/packed-refs; git branch; }
# etiqueta anotada (v2 apunta a un objeto tag, no a un commit)
[ "$(iconv -f latin1 -t utf-8 "$d/R/tag_log.txt")" = "$(git log --oneline v2)" ] && bien "log de una etiqueta anotada" || { mal "log v2:"; cat "$d/R/tag_log.txt"; }
[ "$(git rev-parse de-tag)" = "$(git rev-parse 'v2^{commit}')" ] && bien "branch desde una etiqueta anotada" || { mal "branch de-tag:"; cat "$d/R/tag_branch.txt"; git rev-parse de-tag; }
grep -q "HEAD suelto" "$d/R/tag_checkout.txt" && [ "$(cat .git/HEAD)" = "$(git rev-parse 'v2^{commit}')" ] && bien "checkout de una etiqueta anotada" || { mal "checkout v2:"; cat "$d/R/tag_checkout.txt"; }
[ -z "$(cat "$d/R/tag_status.txt")" ] && bien "limpio en la etiqueta" || { mal "status en v2:"; cat "$d/R/tag_status.txt"; }
[ $fallos -eq 0 ] && echo "TODO BIEN"
exit 0
