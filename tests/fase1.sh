#!/bin/bash
# Fase 1 de dashgit en FS-UAE: init, hash-object, cat-file y config. Después comprueba con el git del PC que el
# repositorio que hizo el Amiga es válido y que los ids coinciden. Acaba con "TODO BIEN" si todo fue bien.
#
#   DASH_KICKSTART=... tests/fase1.sh [DASH_DIR]
set -e
dash=${1:-$HOME/Projects/FreeMEMLang}
aqui=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cp -r "$HOME/.cache/dash-emu/sys31" "$tmp/sys"
chmod -R u+w "$tmp/sys"
"$dash/dash" "$aqui/src/main.dash" -o "$tmp/sys/C/dashgit"
mkdir -p "$tmp/sys/P" "$tmp/sys/S"
printf 'hola\n' > "$tmp/sys/P/hola.txt"
# un fichero de 3000 bytes (varios bloques de SHA-1 y algo que comprimir)
python3 -c "import sys; sys.stdout.write(''.join('linea %d de prueba\n' % i for i in range(160)))" > "$tmp/sys/P/largo.txt"
: > "$tmp/sys/P/vacio.txt"
h=$(git hash-object "$tmp/sys/P/hola.txt")
{
  echo "CD DH0:P"
  echo "dashgit >DH0:r_uso.txt"
  echo "dashgit init >DH0:r_init.txt"
  echo "dashgit init >DH0:r_init2.txt"
  echo "dashgit hash-object hola.txt >DH0:r_hash.txt"
  echo "dashgit hash-object -w hola.txt >DH0:r_hash_w.txt"
  echo "dashgit hash-object -w largo.txt >DH0:r_largo.txt"
  echo "dashgit hash-object -w vacio.txt >DH0:r_vacio.txt"
  echo "dashgit cat-file -t $h >DH0:r_tipo.txt"
  echo "dashgit cat-file -s $h >DH0:r_tam.txt"
  echo "dashgit cat-file -p ${h:0:8} >DH0:r_contenido.txt"
  echo "dashgit config user.name Amiguero >DH0:r_config.txt"
  echo "dashgit config user.name >DH0:r_config2.txt"
  echo "dashgit cosa >DH0:r_mal.txt"
} >> "$tmp/sys/S/Startup-Extra"
cd "$dash" && python3 tools/emu_run.py --timeout ${TIEMPO:-200} --system "$tmp/sys" --keep "$tmp/disco" "$tmp/sys/C/dashgit" >/dev/null 2>&1 || true
d="$tmp/disco"
fallos=0
mira() { # nombre esperado fichero
  if [ "$(cat "$d/$3" 2>/dev/null)" = "$2" ]; then echo "bien $1"; else echo "FALLO $1: $(cat "$d/$3" 2>/dev/null | head -3)"; fallos=$((fallos+1)); fi
}
head -1 "$d/r_uso.txt" | grep -q "dashgit 0.1" && echo "bien uso" || { echo "FALLO uso"; fallos=$((fallos+1)); }
grep -q "Repositorio vacío creado" "$d/r_init.txt" 2>/dev/null || iconv -f latin1 -t utf-8 "$d/r_init.txt" | grep -q "Repositorio vacío creado" && echo "bien init" || { echo "FALLO init: $(cat "$d/r_init.txt")"; fallos=$((fallos+1)); }
grep -q "otra vez" "$d/r_init2.txt" && echo "bien init otra vez" || { echo "FALLO init otra vez"; fallos=$((fallos+1)); }
mira hash "$h" r_hash.txt
mira "hash -w" "$h" r_hash_w.txt
mira largo "$(git hash-object "$d/P/largo.txt")" r_largo.txt
mira vacio "$(git hash-object "$d/P/vacio.txt")" r_vacio.txt
mira tipo blob r_tipo.txt
mira tam 5 r_tam.txt
mira contenido hola r_contenido.txt
mira config2 Amiguero r_config2.txt
grep -q "orden desconocida" "$d/r_mal.txt" && echo "bien orden mala" || { echo "FALLO orden mala"; fallos=$((fallos+1)); }
# el git del PC lee lo que escribió el Amiga
cd "$d/P"
find . -name "*.uaem" -delete
[ "$(git cat-file -p "$h")" = "hola" ] && echo "bien git lee el objeto" || { echo "FALLO git lee el objeto"; fallos=$((fallos+1)); }
git cat-file -p "$(git hash-object largo.txt)" | cmp -s - largo.txt && echo "bien git lee el largo" || { echo "FALLO git lee el largo"; fallos=$((fallos+1)); }
[ "$(git config user.name)" = "Amiguero" ] && echo "bien git lee config" || { echo "FALLO git lee config"; fallos=$((fallos+1)); }
git fsck --strict 2>&1 | grep -v "^dangling\|^notice\|Checking" | head -5
[ "$(git rev-parse --abbrev-ref HEAD 2>&1)" = "HEAD" ] || [ "$(git symbolic-ref HEAD)" = "refs/heads/main" ] && echo "bien HEAD" || { echo "FALLO HEAD"; fallos=$((fallos+1)); }
[ $fallos -eq 0 ] && echo "TODO BIEN"
exit 0
