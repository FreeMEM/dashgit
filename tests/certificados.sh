#!/bin/bash
# Certificados que no se pueden comprobar, en FS-UAE con AmiSSL: un servidor git por https en el PC con un
# certificado autofirmado (tests/servidor_git.py con tls=, el de las pruebas de Dash). dashgit dice el motivo, enseña
# el certificado y pregunta; con "n" o sin entrada no se conecta; con "s" se conecta y lo guarda en
# ENVARC:dashgit/certificados; la siguiente vez (otro dashgit) ya no pregunta; "certificados olvidar" lo olvida y
# vuelve a preguntar; --aceptar-cert lo acepta sin preguntar. Acaba con "TODO BIEN".
#
#   DASH_KICKSTART=... tests/certificados.sh [DASH_DIR]
#   CAPTURAS=cajón: también una vuelta en el Shell, sin redirigir, con capturas de la pregunta y de después
set -e
dash=${1:-$HOME/Projects/FreeMEMLang}
aqui=$(cd "$(dirname "$0")/.." && pwd)
cert="$dash/tests/certs/autofirmado_a.pem"
huella=92:86:4C:8E:ED:2C:AC:97:A7:7B:D4:F5:3C:9E:52:3E:36:3B:8F:D1:26:E2:DA:13:71:05:40:69:CF:C4:BB:77
tmp=$(mktemp -d)
puerto=$((20000 + RANDOM % 20000))
trap 'kill $srv 2>/dev/null; [ -n "$GUARDA" ] || rm -rf "$tmp"' EXIT
sistema() { # cajón: el Workbench 3.1 de las pruebas con AmiSSL
  cp -r "$HOME/.cache/dash-emu/sys31" "$1"
  cp -r "$HOME/.cache/dash-emu/sys31ssl/AmiSSL" "$1/"
  chmod -R u+w "$1"
  mkdir -p "$1/S"
  cat "$HOME/.cache/dash-emu/sys31ssl/S/Startup-Extra" > "$1/S/Startup-Extra"
  # ENVARC:, como en un Workbench (el sistema de las pruebas no lo trae)
  mkdir -p "$1/Prefs/Env-Archive"
  echo "C:Assign ENVARC: SYS:Prefs/Env-Archive" >> "$1/S/Startup-Extra"
  "$dash/dash" "$aqui/src/main.dash" -o "$1/C/dashgit"
}
sistema "$tmp/sys"
mkdir -p "$tmp/srv" "$tmp/obra"
(
  cd "$tmp/obra"
  git init -q -b main
  git config user.name PC; git config user.email pc@pc
  echo "hola" > hola.txt; git add -A; git commit -qm "primero"
  git clone -q --bare . "$tmp/srv/origen.git"
)
tls="$cert" python3 "$aqui/tests/servidor_git.py" "$tmp/srv" $puerto &
srv=$!
sleep 1
url="https://127.0.0.1:$puerto/origen.git"
n=0
r() { n=$((n+1)); printf 'dashgit %s >DH0:R/%02d.txt\n' "$1" $n; }
{
  echo "MakeDir DH0:R"
  echo "CD DH0:"
  echo "Echo \"n\" >DH0:no.txt"
  echo "Echo \"s\" >DH0:si.txt"
  r "clone $url A <DH0:no.txt"                      # 01 dice que no
  r "clone $url A <NIL:"                            # 02 sin nadie que conteste
  r "certificados"                                  # 03 ninguno
  r "clone $url A <DH0:si.txt"                      # 04 dice que sí
  r "certificados"                                  # 05 está
  echo "CD DH0:A"
  r "fetch <NIL:"                                   # 06 otro dashgit: ya no pregunta
  r "certificados olvidar 1"                        # 07
  r "fetch <NIL:"                                   # 08 vuelve a preguntar
  r "--aceptar-cert $huella fetch <DH0:si.txt"      # 09 sin preguntar
  r "certificados"                                  # 10 no lo guarda
  r "--aceptar-cert 12:34 fetch"                    # 11 no es una huella
  r "--aceptar-cert A1:13:B8:DA:89:6D:75:8A:30:33:06:70:18:64:66:A5:BF:7B:B8:91:AA:2F:6E:7F:92:41:7B:2A:9E:20:1D:04 fetch <DH0:si.txt"   # 12 otra huella: no pregunta, falla
  r "fetch <DH0:si.txt"                             # 13 sí otra vez
  r "certificados olvidar 127.0.0.1"                # 14 por servidor
  r "fetch <DH0:si.txt"                             # 15
  r "certificados olvidar --todos"                  # 16
  r "certificados"                                  # 17
  r "certificados olvidar 7"                        # 18 no hay
} >> "$tmp/sys/S/Startup-Extra"
(cd "$dash" && python3 tools/emu_run.py --timeout ${TIEMPO:-400} --set bsdsocket_library=1 --system "$tmp/sys" --keep "$tmp/disco" "$tmp/sys/C/dashgit" >/dev/null 2>&1) || true
d="$tmp/disco"
find "$d" -name "*.uaem" -delete 2>/dev/null || true
fallos=0
ver() { iconv -f latin1 -t utf-8 "$d/R/$1.txt" 2>/dev/null; }
bien() { echo "bien $1"; }
mal() { echo "FALLO $1"; fallos=$((fallos+1)); }
contiene() { if ver $2 | grep -q -- "$3"; then bien "$1"; else mal "$1:"; ver $2 | head -8; fi; }
nocontiene() { if ver $2 | grep -q -- "$3"; then mal "$1:"; ver $2 | head -8; else bien "$1"; fi; }
contiene "aviso" 01 "No se puede comprobar que el servidor 127.0.0.1 sea quien dice ser: self-signed certificate"
contiene "datos del certificado" 01 "Huella SHA-256: $huella"
contiene "pregunta" 01 "¿Aceptar este certificado? (s/N)"
contiene "con n, el motivo real" 01 "dashgit: TLS con 127.0.0.1: self-signed certificate"
nocontiene "con n no clona" 01 "Hecho"
contiene "sin entrada, no" 02 "dashgit: TLS con 127.0.0.1: self-signed certificate"
contiene "ninguno aceptado" 03 "No hay certificados aceptados"
contiene "con s, clona" 04 "Hecho: rama main"
contiene "con s, lo guarda" 04 "Aceptado y guardado en ENVARC:dashgit/certificados"
contiene "lista" 05 "^1  $huella  127.0.0.1  20"
nocontiene "otro dashgit no pregunta" 06 "Aceptar este certificado"
nocontiene "otro dashgit conecta" 06 "dashgit:"
contiene "olvidar 1" 07 "Olvidado: $huella  127.0.0.1"
contiene "olvidado: pregunta otra vez" 08 "Aceptar este certificado"
contiene "olvidado: no conecta" 08 "TLS con 127.0.0.1: self-signed certificate"
nocontiene "--aceptar-cert no pregunta" 09 "Aceptar este certificado"
nocontiene "--aceptar-cert conecta" 09 "dashgit:"
contiene "--aceptar-cert no guarda" 10 "No hay certificados aceptados"
contiene "huella mala" 11 "no es una huella SHA-256: 12:34"
nocontiene "otra huella: no pregunta" 12 "Aceptar este certificado"
contiene "otra huella: no conecta" 12 "TLS con 127.0.0.1: self-signed certificate"
contiene "otra huella: dice cuál es" 12 "aceptar-cert $huella"
contiene "sí otra vez" 13 "Aceptado y guardado"
contiene "olvidar por servidor" 14 "Olvidado: $huella"
contiene "sí otra vez (2)" 15 "Aceptado y guardado"
contiene "olvidar todos" 16 "Olvidado: $huella"
contiene "tras olvidar todos" 17 "No hay certificados aceptados"
contiene "olvidar uno que no hay" 18 "no hay ningún certificado aceptado así: 7"
grep -q "^$huella 127.0.0.1 20" "$d/Prefs/Env-Archive/dashgit/certificados" 2>/dev/null && mal "olvidar --todos no borra el fichero" || bien "el fichero, sin certificados"
[ -f "$d/A/hola.txt" ] && bien "el clon tiene sus ficheros" || mal "el clon no tiene sus ficheros"
for i in $(seq -w 1 $n); do echo "-- $i:"; ver $i; done > "$tmp/salidas.txt"
[ -n "$GUARDA" ] && echo "salidas en $tmp/salidas.txt"
# en el Shell, sin redirigir: la pregunta en una ventana del Shell y un "usuario" (tests/teclea.dash) que contesta
# "s" a los 60 s; las capturas, a los PREGUNTA (45) y DESPUES (90) segundos
if [ -n "$CAPTURAS" ]; then
  mkdir -p "$CAPTURAS"
  sistema "$tmp/sys2"
  mkdir -p "$tmp/sys2/P"
  printf 'CD DH0:\ndashgit clone %s B\ndashgit certificados\n' "$url" > "$tmp/sys2/P/interactivo"
  echo 'NewShell "CON:0/0/640/256/dashgit en el Shell" FROM DH0:P/interactivo' >> "$tmp/sys2/S/Startup-Extra"
  (cd "$dash" && python3 tools/emu_run.py --timeout ${TIEMPO:-200} --set bsdsocket_library=1 --system "$tmp/sys2" \
     --screenshot ${PREGUNTA:-45} "$CAPTURAS/pregunta.png" --screenshot ${DESPUES:-90} "$CAPTURAS/aceptado.png" \
     --keep "$tmp/disco2" "$aqui/tests/teclea.dash" >/dev/null 2>&1) || true
  [ -f "$tmp/disco2/B/hola.txt" ] && bien "en el Shell: clona tras contestar s" || mal "en el Shell: no clona"
  ls "$CAPTURAS"
fi
[ $fallos -eq 0 ] && echo "TODO BIEN"
exit 0
