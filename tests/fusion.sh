#!/bin/bash
# Fusiones de dashgit en FS-UAE: una sin conflictos (cambios en sitios distintos y un fichero nuevo), una con
# conflicto que se resuelve con add y commit, y otra que se deshace con merge --abort. El git del PC comprueba el
# resultado. Acaba con "TODO BIEN".
#
#   DASH_KICKSTART=... tests/fusion.sh [DASH_DIR]
set -e
dash=${1:-$HOME/Projects/FreeMEMLang}
aqui=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cp -r "$HOME/.cache/dash-emu/sys31" "$tmp/sys"
chmod -R u+w "$tmp/sys"
mkdir -p "$tmp/sys/S" "$tmp/sys/P" "$tmp/sys/V"
"$dash/dash" "$aqui/src/main.dash" -o "$tmp/sys/C/dashgit"
"$dash/dash" "$aqui/tests/copia.dash" -o "$tmp/sys/C/copia"
python3 - "$tmp/sys" <<'PY'
import sys
d = sys.argv[1]
base = [f"linea {i}" for i in range(1, 21)]
def w(n, l): open(f"{d}/{n}", "w").write("\n".join(l) + "\n")
w("P/f.txt", base)
o = list(base); o[2] = "tres en otra"; w("V/f_otra.txt", o)
m = list(base); m[14] = "quince en main"; w("V/f_main.txt", m)
both = list(base); both[2] = "tres en otra"; both[14] = "quince en main"; w("V/esperado1.txt", both)
c1 = list(both); c1[9] = "diez en c1"; w("V/f_c1.txt", c1)
cm = list(both); cm[9] = "diez en main"; w("V/f_cm.txt", cm)
marcas = both[:9] + ["<<<<<<< HEAD", "diez en main", "=======", "diez en c1", ">>>>>>> c1"] + both[10:]
w("V/esperado_marcas.txt", marcas)
res = list(both); res[9] = "diez resuelto"; w("V/res.txt", res)
c2 = list(res); c2[0] = "uno en c2"; w("V/f_c2.txt", c2)
m2 = list(res); m2[0] = "uno en main"; w("V/f_m2.txt", m2)
open(f"{d}/V/h.txt", "w").write("nuevo en main\n")
PY
n=0
r() { n=$((n+1)); printf 'dashgit %s >DH0:R/%02d.txt\n' "$1" $n; }
{
  echo "MakeDir DH0:R"
  echo "CD DH0:P"
  echo "dashgit init >NIL:"
  echo "dashgit config user.name Amiga >NIL:"
  echo "dashgit config user.email a@a >NIL:"
  echo "dashgit add . >NIL:"
  echo "dashgit commit -m base >NIL:"
  echo "dashgit checkout -b otra >NIL:"
  echo "copia DH0:V/f_otra.txt f.txt"
  echo "dashgit commit -am en-otra >NIL:"
  echo "dashgit checkout main >NIL:"
  echo "copia DH0:V/f_main.txt f.txt"
  echo "copia DH0:V/h.txt h.txt"
  echo "dashgit add . >NIL:"
  echo "dashgit commit -m en-main >NIL:"
  r "merge otra"                          # 01 sin conflictos
  r "status -s"                           # 02
  echo "copia f.txt DH0:R/f1.txt"
  echo "dashgit checkout -b c1 >NIL:"
  echo "copia DH0:V/f_c1.txt f.txt"
  echo "dashgit commit -am en-c1 >NIL:"
  echo "dashgit checkout main >NIL:"
  echo "copia DH0:V/f_cm.txt f.txt"
  echo "dashgit commit -am diez-en-main >NIL:"
  r "merge c1"                            # 03 conflicto
  r "status -s"                           # 04
  echo "copia f.txt DH0:R/marcas.txt"
  r "commit -m antes-de-resolver"         # 05 no debe dejar
  echo "copia DH0:V/res.txt f.txt"
  r "add f.txt"                           # 06
  r "status -s"                           # 07
  r "commit"                              # 08 con MERGE_MSG
  r "status -s"                           # 09
  echo "dashgit checkout -b c2 >NIL:"
  echo "copia DH0:V/f_c2.txt f.txt"
  echo "dashgit commit -am en-c2 >NIL:"
  echo "dashgit checkout main >NIL:"
  echo "copia DH0:V/f_m2.txt f.txt"
  echo "dashgit commit -am uno-en-main >NIL:"
  r "merge c2"                            # 10 conflicto
  r "merge --abort"                       # 11
  r "status -s"                           # 12
  echo "copia f.txt DH0:R/f_abort.txt"
  r "merge otra"                          # 13 ya al día
} >> "$tmp/sys/S/Startup-Extra"
cd "$dash" && python3 tools/emu_run.py --timeout ${TIEMPO:-500} --system "$tmp/sys" --keep "$tmp/disco" "$tmp/sys/C/dashgit" >/dev/null 2>&1 || true
d="$tmp/disco"
find "$d" -name "*.uaem" -delete
fallos=0
ver() { iconv -f latin1 -t utf-8 "$d/R/$1.txt" 2>/dev/null; }
bien() { echo "bien $1"; }
mal() { echo "FALLO $1"; fallos=$((fallos+1)); }
contiene() { if ver $2 | grep -q -- "$3"; then bien "$1"; else mal "$1:"; ver $2 | head -6; fi; }
contiene "merge sin conflictos" 01 "Fusión hecha"
[ -z "$(ver 02)" ] && bien "limpio tras fusionar" || { mal "status tras fusionar:"; ver 02; }
cmp -s "$d/R/f1.txt" "$d/V/esperado1.txt" && bien "los dos cambios juntos" || { mal "f.txt fusionado:"; diff "$d/R/f1.txt" "$d/V/esperado1.txt"; }
contiene "merge con conflicto" 03 "CONFLICTO en f.txt"
[ "$(ver 04)" = "UU f.txt" ] && bien "status UU" || { mal "status con conflicto:"; ver 04; }
cmp -s "$d/R/marcas.txt" "$d/V/esperado_marcas.txt" && bien "marcas de conflicto" || { mal "marcas:"; diff "$d/R/marcas.txt" "$d/V/esperado_marcas.txt"; }
contiene "commit con conflictos no" 05 "conflictos sin resolver"
[ "$(ver 07)" = "M  f.txt" ] && bien "resuelto con add" || { mal "status tras add:"; ver 07; }
contiene "commit de la fusión" 08 "Merge branch 'c1'"
[ -z "$(ver 09)" ] && bien "limpio tras resolver" || { mal "status tras resolver:"; ver 09; }
contiene "otro conflicto" 10 "CONFLICTO"
contiene "abort" 11 "deshecha"
[ -z "$(ver 12)" ] && bien "limpio tras abort" || { mal "status tras abort:"; ver 12; }
cmp -s "$d/R/f_abort.txt" "$d/V/f_m2.txt" && bien "f.txt como antes del abort" || mal "f.txt tras abort"
contiene "ya al día" 13 "al día"
cd "$d/P"
[ ! -e .git/MERGE_HEAD ] && bien "sin MERGE_HEAD" || mal "queda MERGE_HEAD"
git fsck --strict 2>&1 | grep -iv "dangling\|colgando\|notice\|Checking\|Revisando\|actualizando" | head -5 || true
[ -z "$(git status --porcelain)" ] && bien "git status limpio" || { mal "git status:"; git status --porcelain; }
[ "$(git log --merges --format=%p main | awk '{print NF}' | sort -u)" = "2" ] && [ "$(git log --merges --oneline main | wc -l)" = 2 ] && bien "dos fusiones con dos padres" || { mal "fusiones:"; git log --graph --oneline main | head -20; }
# git da lo mismo al fusionar otra en el main de antes
git checkout -q -b verif main~4 2>/dev/null && git -c user.name=x -c user.email=x@x merge -q --no-edit otra >/dev/null 2>&1 && [ "$(git rev-parse HEAD^{tree})" = "$(git rev-parse main~3^{tree})" ] && bien "el árbol fusionado es el mismo que da git" || { mal "árbol de la fusión distinto del de git"; git log --graph --oneline --all | head -20; }
[ $fallos -eq 0 ] && echo "TODO BIEN"
exit 0
