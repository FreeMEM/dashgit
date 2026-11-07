#!/bin/bash
# Un disco FFS sin nombres largos (30 letras como mucho, un disquete en DF0:): git necesita 50 (los ficheros de
# .git/objects), así que dashgit init y las demás órdenes lo dicen claro en vez de fallar a medias; en DH0: (nombres
# largos) init sigue funcionando. Necesita xdftool (amitools: XDFTOOL=ruta). Acaba con "TODO BIEN".
#
#   DASH_KICKSTART=... XDFTOOL=... tests/ffs.sh [DASH_DIR]
set -e
dash=${1:-$HOME/Projects/FreeMEMLang}
xdf=${XDFTOOL:-xdftool}
aqui=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cp -r "$HOME/.cache/dash-emu/sys31" "$tmp/sys"
chmod -R u+w "$tmp/sys"
mkdir -p "$tmp/sys/S"
"$dash/dash" "$aqui/src/main.dash" -o "$tmp/sys/C/dashgit"
"$xdf" "$tmp/ffs.adf" create + format Corto ffs >/dev/null
{
  echo "MakeDir DH0:R"
  echo "MakeDir DF0:P"
  echo "CD DF0:P"
  echo "dashgit init >DH0:R/1.txt"
  echo "dashgit status >DH0:R/2.txt"
  echo "MakeDir DH0:Q"
  echo "CD DH0:Q"
  echo "dashgit init >DH0:R/3.txt"
  echo "dashgit status >DH0:R/4.txt"
} >> "$tmp/sys/S/Startup-Extra"
cd "$dash" && python3 tools/emu_run.py --timeout ${TIEMPO:-200} --system "$tmp/sys" --keep "$tmp/disco" \
    --set floppy_drive_0="$tmp/ffs.adf" "$tmp/sys/C/dashgit" >/dev/null 2>&1 || true
d="$tmp/disco"
fallos=0
ver() { iconv -f latin1 -t utf-8 "$d/R/$1.txt" 2>/dev/null; }
bien() { echo "bien $1"; }
mal() { echo "FALLO $1"; fallos=$((fallos+1)); }
ver 1 | grep -q "solo admite nombres de hasta 30 letras" && bien "init en FFS lo dice" || { mal "init en FFS:"; ver 1; }
ver 2 | grep -q "solo admite nombres de hasta 30 letras" && bien "status en FFS lo dice" || { mal "status en FFS:"; ver 2; }
ver 3 | grep -q "Repositorio vacío creado" && bien "init en DH0: funciona" || { mal "init en DH0:"; ver 3; }
ver 4 | grep -qi "rama main" && bien "status en DH0: funciona" || { mal "status en DH0:"; ver 4; }
[ $fallos -eq 0 ] && echo "TODO BIEN"
exit 0
