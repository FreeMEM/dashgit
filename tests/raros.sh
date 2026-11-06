#!/bin/bash
# Casos raros en FS-UAE, comparados con el git del PC: nombres con acentos (Latin-1 en el Amiga, UTF-8 en git),
# cajones anidados, nombres que se ordenan raro ("a", "a.b", "a-b/", "a/"), un fichero vacío, uno sin salto final,
# uno binario de 100 KB, borrar un cajón entero y volver atrás con checkout; y una rama hecha en el PC con nombres
# que el Amiga no puede escribir ("€", japonés, ":", dos que solo cambian en mayúsculas): se saltan con un aviso,
# sin pisar nada, y status no los da por borrados. Acaba con "TODO BIEN".
#
#   DASH_KICKSTART=... tests/raros.sh [DASH_DIR]
set -e
dash=${1:-$HOME/Projects/FreeMEMLang}
aqui=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap '[ -n "$GUARDA" ] || rm -rf "$tmp"' EXIT
cp -r "$HOME/.cache/dash-emu/sys31" "$tmp/sys"
chmod -R u+w "$tmp/sys"
mkdir -p "$tmp/sys/S" "$tmp/sys/P"
"$dash/dash" "$aqui/src/main.dash" -o "$tmp/sys/C/dashgit"
"$dash/dash" "$aqui/tests/copia.dash" -o "$tmp/sys/C/copia"
python3 - "$tmp/sys/P" <<'PY'
import os, sys, random
d = sys.argv[1]
def w(rel, data):
    p = os.path.join(d, rel.encode("latin-1").decode("latin-1"))
    os.makedirs(os.path.dirname(p), exist_ok=True)
    open(p.encode("latin-1") if False else p, "wb").write(data)
# en el PC los nombres van en UTF-8; FS-UAE se los da al Amiga en Latin-1
def wl(rel, data):
    p = os.path.join(d.encode(), rel.encode("utf-8"))
    os.makedirs(os.path.dirname(p), exist_ok=True)
    open(p, "wb").write(data)
wl("canción.txt", "la letra\n".encode())
wl("año/niño.txt", b"dentro\n")
wl("a", b"a\n")
wl("a.b", b"a.b\n")
wl("a-b/x", b"x\n")
wl("a0/y", b"y\n")
wl("hondo/uno/dos/tres/fondo.txt", b"muy dentro\n")
wl("vacio.txt", b"")
wl("sin_salto.txt", b"no acaba en salto")
random.seed(5)
wl("binario.bin", bytes(random.randrange(256) for _ in range(100000)))
PY
# N: main con README y otro.txt; la rama raros (hecha sin tocar el disco) añade los nombres imposibles, un
# "readme" que solo cambia en mayúsculas, un cajón "Otro.txt/" que choca con el fichero y un nombre largo
mkdir -p "$tmp/sys/N"
(
  cd "$tmp/sys/N"; git init -q -b main; git config user.name PC; git config user.email p@p
  printf 'el de main\n' > README; printf 'otro\n' > otro.txt; git add -A; git commit -qm main
  python3 - > fi.txt <<'PY'
import sys
largo = "un-nombre-de-mas-de-treinta-letras-largo.txt"
fs = {"README": "el de main\n", "otro.txt": "otro\n", "€uro.txt": "euro\n", "日本.txt": "japonés\n",
      "a:b.txt": "dos puntos\n", "readme": "el pequeño\n", "OTRO.TXT/x": "cajón\n", largo: "largo\n"}
out = sys.stdout.buffer
msg = b"raros\n"
out.write(b"commit refs/heads/raros\ncommitter PC <p@p> 1700000000 +0000\ndata %d\n%sfrom refs/heads/main\n" % (len(msg), msg))
for k, v in fs.items():
    b = v.encode()
    out.write(b"M 100644 inline %s\ndata %d\n%s\n" % (k.encode(), len(b), b))
out.write(b"\n")
PY
  git fast-import --quiet < fi.txt; rm fi.txt
)
chmod -R u+w "$tmp/sys/N"
mkdir -p "$tmp/sys/V"; printf 'cambiado en el amiga\n' > "$tmp/sys/V/otro_cambiado.txt"
n=0
r() { n=$((n+1)); printf 'dashgit %s >DH0:R/%02d.txt\n' "$1" $n; }
{
  echo "MakeDir DH0:R"
  echo "CD DH0:P"
  echo "dashgit init >NIL:"
  echo "dashgit config user.name Amiga >NIL:"
  echo "dashgit config user.email a@a >NIL:"
  r "add ."                     # 01
  r "status -s"                 # 02
  r "commit -m todo"            # 03
  r "status -s"                 # 04
  r "rm hondo"                  # 05  sin -r: no
  r "rm -r hondo"               # 06
  r "commit -m sin-hondo"       # 07
  r "checkout -b vuelta HEAD"   # 08
  r "checkout main"             # 09
  r "log --oneline"             # 10
  r "status -s"                 # 11
  echo "Echo \"cambiado\" >a"
  r "rm a"                      # 12  con cambios: no
  r "rm a.b noexiste"           # 13  uno que no está: no se borra nada
  r "rm --cached a.b"           # 14  sale del índice, queda en el disco
  r "rm -f a"                   # 15  con cambios, forzado
  r "status -s"                 # 16
  echo "CD DH0:N"
  echo "dashgit checkout raros >DH0:R/n1.txt"
  echo "dashgit status -s >DH0:R/n2.txt"
  echo "copia DH0:V/otro_cambiado.txt otro.txt"
  echo "dashgit commit -am cambio >DH0:R/n3.txt"
  echo "dashgit checkout main >DH0:R/n4.txt"
  echo "dashgit status -s >DH0:R/n5.txt"
} >> "$tmp/sys/S/Startup-Extra"
cd "$dash" && python3 tools/emu_run.py --timeout ${TIEMPO:-500} --system "$tmp/sys" --keep "$tmp/disco" "$tmp/sys/C/dashgit" >/dev/null 2>&1 || true
d="$tmp/disco"
set +e
find "$d" -name "*.uaem" -delete
fallos=0
ver() { iconv -f latin1 -t utf-8 "$d/R/$1.txt" 2>/dev/null; }
bien() { echo "bien $1"; }
mal() { echo "FALLO $1"; fallos=$((fallos+1)); }
# lo que git habría hecho con los mismos ficheros (en UTF-8)
ref="$tmp/ref"; mkdir -p "$ref"
python3 - "$tmp/sys/P" "$ref" <<'PY'
import os, sys, shutil
src, dst = sys.argv[1].encode(), sys.argv[2].encode()
for raiz, dirs, fs in os.walk(src):
    for f in fs:
        p = os.path.join(raiz, f)
        rel = os.path.relpath(p, src)
        q = os.path.join(dst, rel)
        os.makedirs(os.path.dirname(q), exist_ok=True)
        shutil.copyfile(p, q)
PY
(cd "$ref" && git init -q && git add -A && git -c user.name=x -c user.email=x@x commit -qm x)
esperado=$(cd "$ref" && git -c core.quotepath=off ls-files | sort | sed 's/^/A  /')
[ "$(ver 02 | sort)" = "$esperado" ] && bien "status -s de todo" || { mal "status -s:"; diff <(ver 02 | sort) <(echo "$esperado"); }
cd "$d/P"
[ "$(git rev-parse 'main~1^{tree}')" = "$(git -C "$ref" rev-parse 'HEAD^{tree}')" ] && bien "el mismo árbol que git (nombres, orden, binario, vacío)" || { mal "árbol distinto:"; diff <(git -c core.quotepath=off ls-tree -r main~1) <(git -C "$ref" -c core.quotepath=off ls-tree -r HEAD); }
git fsck --strict 2>&1 | grep -iv "dangling\|colgando\|notice\|Checking\|Revisando\|actualizando" | head -5 || true
[ -z "$(ver 04)" ] && bien "limpio tras el commit" || { mal "status tras commit:"; ver 04; }
[ ! -e "$d/P/hondo" ] && bien "rm quita el cajón" || { mal "queda el cajón hondo:"; find "$d/P/hondo"; }
grep -q "sin -r" "$d/R/05.txt" && [ -e "$tmp/sys/P/hondo" ] && bien "rm de un cajón pide -r" || { mal "rm sin -r:"; ver 05; }
[ -z "$(ver 11)" ] && bien "limpio tras volver" || { mal "status tras volver:"; ver 11; }
ver 12 | grep -q "cambios que se perderían" && bien "rm se niega con cambios" || { mal "rm con cambios:"; ver 12; }
grep -q "no se ha borrado nada" "$d/R/13.txt" && bien "rm con una ruta mala no borra nada" || { mal "rm con ruta mala:"; ver 13; }
[ -e "$d/P/a.b" ] && bien "rm --cached deja el fichero" || mal "rm --cached borró el fichero"
[ ! -e "$d/P/a" ] && bien "rm -f borra" || mal "rm -f no borró"
[ "$(ver 16)" = "$(printf 'D  a\nD  a.b\n?? a.b')" ] && bien "status tras los rm" || { mal "status tras los rm:"; ver 16; }
git -c core.quotepath=off status --porcelain > "$tmp/gs.txt"
[ "$(cat "$tmp/gs.txt")" = "$(printf 'D  a\nD  a.b\n?? a.b')" ] && bien "git status igual" || { mal "git status:"; cat "$tmp/gs.txt"; }
cmp -s "$d/P/binario.bin" "$tmp/sys/P/binario.bin" && bien "binario intacto" || mal "binario"
[ "$(git cat-file -p main~1:sin_salto.txt)" = "no acaba en salto" ] && bien "sin salto final" || mal "sin salto final"
# nombres que el Amiga no puede escribir
v() { iconv -f latin1 -t utf-8 "$d/R/$1.txt" 2>/dev/null; }
[ "$(v n1 | grep -c 'se salta')" = 5 ] && v n1 | grep -q "Cambiado a la rama raros" && bien "checkout salta los 5 imposibles" || { mal "checkout raros:"; v n1; }
[ -z "$(v n2)" ] && bien "status no los da por borrados" || { mal "status en raros:"; v n2; }
cd "$d/N"
[ "$(git log -1 --format=%s raros)" = "cambio" ] && [ "$(git ls-tree --name-only raros | wc -l)" = 8 ] && [ "$(git show raros:otro.txt)" = "cambiado en el amiga" ] && [ "$(git show raros:readme)" = "el pequeño" ] && bien "commit -a los conserva" || { mal "commit en raros:"; v n3; git -c core.quotepath=off ls-tree -r raros; }
grep -q "Cambiado a la rama main" "$d/R/n4.txt" && [ "$(cat "$d/N/README")" = "el de main" ] && bien "volver a main no borra README" || { mal "checkout main:"; v n4; ls -la "$d/N"; }
[ "$(ls -A "$d/N" | LC_ALL=C sort | tr '\n' ' ')" = ".git README otro.txt " ] && bien "nada de más en el disco" || { mal "en el disco:"; ls -A "$d/N"; }
[ -z "$(v n5)" ] && [ -z "$(git status --porcelain)" ] && bien "limpio en main" || { mal "status en main:"; v n5; git status --porcelain; }
[ $fallos -eq 0 ] && echo "TODO BIEN"
exit 0
