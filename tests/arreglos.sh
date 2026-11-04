#!/bin/bash
# Los arreglos de la revisión del 2026-11-04, en FS-UAE y comparados con el git del PC:
#  - cambiar de rama conserva los cambios sin commit (en el disco y añadidos) de los ficheros que no cambian;
#  - un fichero "a" que pasa a cajón "a/" con add, y checkout entre una rama con el fichero y otra con el cajón;
#  - merge-base en un caso con dos antepasados comunes (el bueno es el de git);
#  - fusión con una última línea sin salto: conflicto, como git.
# Acaba con "TODO BIEN".
#
#   DASH_KICKSTART=... tests/arreglos.sh [DASH_DIR]
set -e
dash=${1:-$HOME/Projects/FreeMEMLang}
aqui=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap '[ -n "$GUARDA" ] || rm -rf "$tmp"' EXIT
cp -r "$HOME/.cache/dash-emu/sys31" "$tmp/sys"
chmod -R u+w "$tmp/sys"
mkdir -p "$tmp/sys/S" "$tmp/sys/P" "$tmp/sys/V" "$tmp/sys/M"
"$dash/dash" "$aqui/src/main.dash" -o "$tmp/sys/C/dashgit"
"$dash/dash" "$aqui/tests/copia.dash" -o "$tmp/sys/C/copia"
printf 'leeme\n' > "$tmp/sys/P/README"
printf 'otro\n' > "$tmp/sys/P/otro.txt"
printf 'nada\n' > "$tmp/sys/P/a"
printf 'otro en b\n' > "$tmp/sys/V/otro_b.txt"
printf 'leeme cambiado\n' > "$tmp/sys/V/README2"
printf 'dentro\n' > "$tmp/sys/V/x"
# el repositorio M (hecho en el PC) para merge-base: main A-B-C-D, X1 sale de B, la rama f sale de C y fusiona X1
(
  cd "$tmp/sys/M"; git init -q -b main; git config user.name PC; git config user.email p@p
  c() { echo "$1" > "$2"; git add -A; git commit -qm "$1"; }
  c A f1; c B f2; git branch x; c C f3; git checkout -q -b f; c F1 f4; c F2 f5; c F3 f6
  git checkout -q x; c X1 f7; git checkout -q f; git merge -q --no-edit x
  git checkout -q main; c D f8
  git merge-base main f > "$tmp/esperado_base.txt"
  # sin salto final: base "x\ny", main "X\ny", s "x\ny\nz\n"
  printf 'x\ny' > t.txt; git add t.txt; git commit -qm base-t
  git checkout -q -b s; printf 'x\ny\nz\n' > t.txt; git commit -qam s-t
  git checkout -q main; printf 'X\ny' > t.txt; git commit -qam main-t
  git checkout -q -b prueba-pc; git merge -q --no-edit s >/dev/null 2>&1 && echo limpio > "$tmp/esperado_salto.txt" || echo conflicto > "$tmp/esperado_salto.txt"
  git merge --abort 2>/dev/null || true; git checkout -q main; git branch -q -D prueba-pc
)
chmod -R u+w "$tmp/sys/M"
n=0
r() { n=$((n+1)); printf 'dashgit %s >DH0:R/%02d.txt\n' "$1" $n; }
{
  echo "MakeDir DH0:R"
  echo "CD DH0:P"
  echo "dashgit init >NIL:"
  echo "dashgit config user.name Amiga >NIL:"
  echo "dashgit config user.email a@a >NIL:"
  echo "dashgit add . >NIL:"
  echo "dashgit commit -m uno >NIL:"
  echo "dashgit checkout -b b >NIL:"
  echo "copia DH0:V/otro_b.txt otro.txt"
  echo "dashgit commit -am otro-en-b >NIL:"
  echo "dashgit checkout main >NIL:"
  # cambios sin commit en README (que es igual en main y en b) y uno añadido
  echo "copia DH0:V/README2 README"
  echo "Echo \"nuevo\" >nuevo.txt"
  r "add nuevo.txt"                 # 01
  r "checkout b"                    # 02
  r "status -s"                     # 03  " M README" y "A  nuevo.txt"
  r "checkout main"                 # 04
  r "status -s"                     # 05  igual
  r "commit -am guarda"             # 06
  # el fichero "a" pasa a ser un cajón "a/"
  r "rm a"                          # 07
  echo "MakeDir a"
  echo "copia DH0:V/x a/x"
  r "add a/x"                       # 08
  r "commit -m a-cajon"             # 09
  r "checkout b"                    # 10  b tiene el fichero "a"
  echo "copia a DH0:R/a_en_b.txt"
  r "checkout main"                 # 11  main tiene el cajón "a/"
  echo "copia a/x DH0:R/ax_en_main.txt"
  r "status -s"                     # 12
  echo "CD DH0:M"
  r "merge-base main f"             # 13
  r "merge s"                       # 14  sin salto final
} >> "$tmp/sys/S/Startup-Extra"
cd "$dash" && python3 tools/emu_run.py --timeout ${TIEMPO:-500} --system "$tmp/sys" --keep "$tmp/disco" "$tmp/sys/C/dashgit" >/dev/null 2>&1 || true
d="$tmp/disco"
set +e
find "$d" -name "*.uaem" -delete
fallos=0
ver() { iconv -f latin1 -t utf-8 "$d/R/$1.txt" 2>/dev/null; }
bien() { echo "bien $1"; }
mal() { echo "FALLO $1"; fallos=$((fallos+1)); }
[ "$(ver 03)" = "$(printf 'A  nuevo.txt\n M README')" ] && bien "checkout conserva los cambios" || { mal "status tras checkout b:"; ver 02; ver 03; }
[ "$(ver 05)" = "$(printf 'A  nuevo.txt\n M README')" ] && bien "y al volver también" || { mal "status tras volver:"; ver 04; ver 05; }
[ "$(cat "$d/R/a_en_b.txt" 2>/dev/null)" = "nada" ] && bien "checkout de cajón a fichero" || { mal "a en b:"; ver 10; }
[ "$(cat "$d/R/ax_en_main.txt" 2>/dev/null)" = "dentro" ] && bien "checkout de fichero a cajón" || { mal "a/x en main:"; ver 11; }
[ -z "$(ver 12)" ] && bien "limpio" || { mal "status:"; ver 12; }
[ "$(ver 13)" = "$(cat "$tmp/esperado_base.txt")" ] && bien "merge-base como git" || { mal "merge-base: $(ver 13) en vez de $(cat "$tmp/esperado_base.txt")"; }
if [ "$(cat "$tmp/esperado_salto.txt")" = conflicto ]; then
  ver 14 | grep -q CONFLICTO && bien "sin salto final: conflicto como git" || { mal "sin salto final:"; ver 14; }
else
  ver 14 | grep -q "Fusión hecha" && bien "sin salto final: limpio como git" || { mal "sin salto final:"; ver 14; }
fi
cd "$d/P"
git fsck --strict 2>&1 | grep -iv "dangling\|colgando\|notice\|Checking\|Revisando\|actualizando" | head -5
[ "$(git ls-tree --name-only main)" = "$(printf 'README\na\nnuevo.txt\notro.txt')" ] && [ "$(git ls-tree -r --name-only main | grep -c '^a')" = 1 ] && bien "árbol sin fichero y cajón a la vez" || { mal "árbol:"; git ls-tree -r main; }
[ -z "$(git status --porcelain)" ] && bien "git status limpio" || { mal "git status:"; git status --porcelain; }
[ $fallos -eq 0 ] && echo "TODO BIEN"
exit 0
