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
# muchas líneas distintas en los dos lados: (x + 1) * (y + 1) no cabe en 32 bits
open(f"{d}/P/grande.txt", "w").write("".join(f"a{i}\n" for i in range(47000)))
open(f"{d}/V/grande2.txt", "w").write("".join(f"b{i}\n" for i in range(47000)))
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
  echo "dashgit commit -m dos >NIL:"
  echo "copia DH0:V/grande2.txt grande.txt"
  echo "dashgit diff grande.txt >DH0:R/grande.txt"
} >> "$tmp/sys/S/Startup-Extra"
cd "$dash" && python3 tools/emu_run.py --timeout ${TIEMPO:-300} --system "$tmp/sys" --keep "$tmp/disco" "$tmp/sys/C/dashgit" >/dev/null 2>&1 || true
d="$tmp/disco"
cd "$d/P"
find . -name "*.uaem" -delete
fallos=0
# lo que el Amiga vio antes del commit "dos" es lo que hay entre "uno" y "dos"
git -c core.quotepath=off diff HEAD~1 HEAD -- f.txt > "$tmp/esperado_diff.txt" 2>/dev/null || true
# las líneas index llevan modos y abreviaturas: fuera
limpia() { grep -av '^index ' "$1" | sed 's/^\(@@ [^@]* @@\).*/\1/'; }
if diff <(limpia "$tmp/esperado_diff.txt") <(limpia "$d/R/diff.txt") >/dev/null; then echo "bien diff"; else echo "FALLO diff:"; diff <(limpia "$tmp/esperado_diff.txt") <(limpia "$d/R/diff.txt") | head -20; fallos=$((fallos+1)); fi
git -c core.quotepath=off diff HEAD~1 HEAD > "$tmp/esperado_cached.txt"
if diff <(limpia "$tmp/esperado_cached.txt") <(limpia "$d/R/cached.txt") >/dev/null; then echo "bien diff --cached"; else echo "FALLO diff --cached:"; diff <(limpia "$tmp/esperado_cached.txt") <(limpia "$d/R/cached.txt") | head -30; fallos=$((fallos+1)); fi
[ "$(grep -c '^-a' "$d/R/grande.txt")" = 47000 ] && [ "$(grep -c '^+b' "$d/R/grande.txt")" = 47000 ] && grep -q '^@@ -1,47000 +1,47000 @@' "$d/R/grande.txt" && echo "bien diff de 47000 líneas distintas" || { echo "FALLO diff grande:"; head -3 "$d/R/grande.txt"; fallos=$((fallos+1)); }
[ ! -s "$d/R/vacio.txt" ] && echo "bien diff vacío" || { echo "FALLO diff vacío:"; head "$d/R/vacio.txt"; fallos=$((fallos+1)); }
[ $fallos -eq 0 ] && echo "TODO BIEN"
exit 0
