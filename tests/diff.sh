#!/bin/bash
# diff de dashgit en FS-UAE, comparado con el git diff del PC sobre el mismo repositorio. Acaba con "TODO BIEN".
#
#   DASH_KICKSTART=... tests/diff.sh [DASH_DIR]
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
a = [f"línea {i}" for i in range(1, 31)]
open(f"{d}/P/f.txt", "w", encoding="latin-1").write("\n".join(a) + "\n")
b = list(a); b[2] = "línea 3 cambiada"; del b[9]; b.insert(20, "una nueva"); b.append("al final")
open(f"{d}/V/f2.txt", "w", encoding="latin-1").write("\n".join(b) + "\n")
open(f"{d}/P/g.txt", "w").write("se borra\n")
open(f"{d}/V/h.txt", "w").write("nueva\nsin salto")
PY
{
  echo "MakeDir DH0:R"
  echo "CD DH0:P"
  echo "dashgit init >NIL:"
  echo "dashgit config user.name Prueba >NIL:"
  echo "dashgit config user.email p@p >NIL:"
  echo "dashgit add . >NIL:"
  echo "dashgit commit -m uno >NIL:"
  echo "copia DH0:V/f2.txt f.txt"
  echo "dashgit diff >DH0:R/diff.txt"
  echo "copia DH0:V/h.txt h.txt"
  echo "dashgit rm g.txt >NIL:"
  echo "dashgit add . >NIL:"
  echo "dashgit diff --cached >DH0:R/cached.txt"
  echo "dashgit diff >DH0:R/vacio.txt"
} >> "$tmp/sys/S/Startup-Extra"
cd "$dash" && python3 tools/emu_run.py --timeout ${TIEMPO:-300} --system "$tmp/sys" --keep "$tmp/disco" "$tmp/sys/C/dashgit" >/dev/null 2>&1 || true
d="$tmp/disco"
cd "$d/P"
find . -name "*.uaem" -delete
fallos=0
# el diff del árbol de trabajo: el de git con el f.txt cambiado y el índice de antes (de "uno")
git -c core.quotepath=off diff HEAD -- f.txt > "$tmp/esperado_diff.txt" 2>/dev/null || true
# git diff HEAD da f.txt contra HEAD; quitamos las líneas index, que llevan modos y abreviaturas
limpia() { grep -av '^index ' "$1" | sed 's/^\(@@ [^@]* @@\).*/\1/'; }
if diff <(limpia "$tmp/esperado_diff.txt") <(limpia "$d/R/diff.txt") >/dev/null; then echo "bien diff"; else echo "FALLO diff:"; diff <(limpia "$tmp/esperado_diff.txt") <(limpia "$d/R/diff.txt") | head -20; fallos=$((fallos+1)); fi
git -c core.quotepath=off diff --cached > "$tmp/esperado_cached.txt"
if diff <(limpia "$tmp/esperado_cached.txt") <(limpia "$d/R/cached.txt") >/dev/null; then echo "bien diff --cached"; else echo "FALLO diff --cached:"; diff <(limpia "$tmp/esperado_cached.txt") <(limpia "$d/R/cached.txt") | head -30; fallos=$((fallos+1)); fi
[ ! -s "$d/R/vacio.txt" ] && echo "bien diff vacío" || { echo "FALLO diff vacío:"; head "$d/R/vacio.txt"; fallos=$((fallos+1)); }
[ $fallos -eq 0 ] && echo "TODO BIEN"
exit 0
