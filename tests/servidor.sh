#!/bin/bash
# "dashgit servidor" en FS-UAE: tests/cliente.dash lo arranca y le manda órdenes por ARexx y por ficheros
# (ENV:dashgit/DGP.pedido); se compara con lo que da dashgit en el Shell y con lo esperado de --texto. También los
# tiempos (servidor frente a Shell), la memoria tras 200 pedidos, ADIOS y que acaba al irse su dueño.
# Acaba con "TODO BIEN".
#
#   DASH_KICKSTART=... [REAL=1] tests/servidor.sh [DASH_DIR]
set -e
dash=${1:-$HOME/Projects/FreeMEMLang}
aqui=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap '[ -n "$GUARDAR" ] && cp -r "$tmp" "$GUARDAR"; rm -rf "$tmp"' EXIT
cp -r "$HOME/.cache/dash-emu/sys31" "$tmp/sys"
chmod -R u+w "$tmp/sys"
mkdir -p "$tmp/sys/S" "$tmp/sys/P" "$tmp/sys/Q" "$tmp/sys/V"
"$dash/dash" "$aqui/src/main.dash" -o "$tmp/sys/C/dashgit"
"$dash/dash" "$aqui/tests/copia.dash" -o "$tmp/sys/C/copia"
"$dash/dash" "$aqui/tests/cliente.dash" -o "$tmp/sys/C/cliente"
python3 - "$tmp/sys" <<'PY'
import sys
d = sys.argv[1]
w = lambda p, t: open(p, "w", encoding="latin-1").write(t)
a = [f"línea {i}" for i in range(1, 41)]
w(f"{d}/P/a.txt", "\n".join(a) + "\n")
b = list(a); b[2] = "línea 3 cambiada"; del b[9]; b.insert(20, "una nueva"); b.insert(21, "y otra"); b.append("al final")
w(f"{d}/V/a2.txt", "\n".join(b) + "\n")
e = list(a); e[4] = "cambiada en el editor"; del e[14]; e.insert(30, "puesta en el editor")
w(f"{d}/V/editor.txt", "\n".join(e) + "\n")
w(f"{d}/V/sinsalto.txt", "\n".join(a[:-3] + ["otra"]))
w(f"{d}/P/b.txt", "be\n")
g = [f"{i}: una línea de un fichero grande, con algo de texto para que pese" for i in range(1, 501)]
w(f"{d}/P/grande.txt", "\n".join(g) + "\n")
g2 = list(g); g2[10] = "cambiada"; g2.insert(200, "nueva"); del g2[400]
w(f"{d}/V/grande2.txt", "\n".join(g2) + "\n")
w(f"{d}/V/u.txt", "sin seguir\n")
w(f"{d}/Q/q.txt", "q\n")
PY
{
  echo "MakeDir DH0:R"
  echo "MakeDir DH0:Prueba DH0:Prueba/juego"
  echo "CD DH0:Prueba/juego"
  echo "copia DH0:V/u.txt j.txt"
  echo "dashgit init >NIL:"
  echo "dashgit config user.name Prueba >NIL:"
  echo "dashgit config user.email p@p >NIL:"
  echo "dashgit add . >NIL:"
  echo "dashgit commit -m uno >NIL:"
  echo "copia DH0:V/u.txt k.txt"
  echo "CD DH0:Q"
  echo "dashgit init >NIL:"
  echo "CD DH0:P"
  echo "dashgit init >NIL:"
  echo "dashgit config user.name Prueba >NIL:"
  echo "dashgit config user.email p@p >NIL:"
  echo "dashgit add . >NIL:"
  echo "dashgit commit -m uno >NIL:"
  echo "copia DH0:V/a2.txt a.txt"
  echo "copia DH0:V/u.txt u.txt"
  echo "dashgit add b.txt >NIL:"
  echo "dashgit status --porcelain -b >DH0:R/c_0.txt"
  echo "dashgit branch --show-current >DH0:R/c_1.txt"
  echo "dashgit diff >DH0:R/c_2.txt"
  echo "dashgit diff --rangos HEAD -- a.txt >DH0:R/c_3.txt"
  echo "dashgit log --format=%H|%s >DH0:R/c_4.txt"
  echo "dashgit diff --cached --name-status >DH0:R/c_5.txt"
  echo "dashgit diff --rangos --texto DH0:V/editor.txt -- a.txt >DH0:R/c_texto.txt"
  echo "dashgit diff --rangos HEAD --texto DH0:V/grande2.txt -- grande.txt >DH0:R/c_grande.txt"
  echo "CD DH0:"
  echo "cliente"
} >> "$tmp/sys/S/Startup-Extra"
cd "$dash" && python3 tools/emu_run.py --timeout ${TIEMPO:-900} --system "$tmp/sys" ${REAL:+--set uae_cpu_speed=real} --keep "$tmp/disco" "$tmp/sys/C/copia" >/dev/null 2>&1 || true
d="$tmp/disco"
R="$d/R"
fallos=0
igual() {  # igual nombre esperado obtenido
  cat "$2" > "$tmp/esperado" 2>/dev/null || true
  if diff "$tmp/esperado" "$3" >/dev/null 2>&1; then echo "bien $1"; else echo "FALLO $1:"; diff "$tmp/esperado" "$3" 2>&1 | head -20; fallos=$((fallos+1)); fi
}
cat "$R/cliente.log" 2>/dev/null
for i in 0 1 2 3 4 5; do
  igual "orden $i por ficheros ($(sed -n "$((i+1))p" <<< $'status --porcelain -b\nbranch --show-current\ndiff\ndiff --rangos\nlog --format\ndiff --cached --name-status'))" "$R/c_$i.txt" "$R/sf_$i.txt"
  igual "orden $i por ARexx" "$R/c_$i.txt" "$R/sa_$i.txt"
done
igual "add por el servidor" <(printf 'M  a.txt\n?? u.txt\n') "$R/sf_add.txt"
igual "reset por ARexx" <(printf ' M a.txt\n?? u.txt\n') "$R/sa_reset.txt"
# los rangos esperados de editor.txt frente a a.txt (HEAD), con el diff -U0 del PC
rangos_de() {  # rangos_de viejo nuevo ruta: los rangos que salen del diff -U0 del PC
python3 - "$1" "$2" "$3" <<'PY'
import re, subprocess, sys
o = subprocess.run(["diff", "-U0", sys.argv[1], sys.argv[2]], capture_output=True, text=True, encoding="latin-1").stdout
print("F " + sys.argv[3])
for l in o.splitlines():
    m = re.match(r"@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@", l)
    if not m: continue
    q = int(m.group(2) or 1) if m.group(2) != "0" else 0
    p = int(m.group(4) or 1) if m.group(4) != "0" else 0
    n = int(m.group(3)) if p > 0 else int(m.group(3)) + 1
    c = min(q, p)
    if c: print(f"C {n} {c}")
    if p > c: print(f"A {n + c} {p - c}")
    elif q > c: print(f"B {n + c} {q - c}")
PY
}
rangos_de "$tmp/sys/P/a.txt" "$tmp/sys/V/editor.txt" a.txt > "$tmp/e_texto.txt"
igual "--texto sin salto de línea al final" <(rangos_de "$tmp/sys/P/a.txt" "$tmp/sys/V/sinsalto.txt" a.txt) "$R/sf_texto_sinsalto.txt"
igual "--texto en el Shell" "$tmp/e_texto.txt" "$R/c_texto.txt"
igual "--texto - por ficheros" "$tmp/e_texto.txt" "$R/sf_texto.txt"
igual "--texto - por ARexx" "$tmp/e_texto.txt" "$R/sa_texto.txt"
igual "--texto de un fichero nuevo" <(printf 'F nuevo.txt\nA 1 2\n') "$R/sf_texto_nuevo.txt"
igual "--texto sin commits" <(printf 'F q.txt\nA 1 1\n') "$R/sf_texto_vacio.txt"
igual "--texto grande, Shell y servidor" "$R/c_grande.txt" "$R/sf_grande.txt"
grep -q "en el servidor no" "$R/sf_push.txt" && grep -q "rc 10" "$R/sf_push.txt" && echo "bien push no va en el servidor" || { echo "FALLO push:"; cat "$R/sf_push.txt"; fallos=$((fallos+1)); }
grep -aq "no existe el caj" "$R/sf_cajon.txt" && grep -q "rc 10" "$R/sf_cajon.txt" && echo "bien cajón que no existe" || { echo "FALLO cajón:"; cat "$R/sf_cajon.txt"; fallos=$((fallos+1)); }
igual "push por ARexx: RC 10" <(echo "rc 10") "$R/sa_push.txt"
igual "ADIOS" <(echo true) "$R/adios.txt"
igual "sin su dueño, acaba" <(echo "true true") "$R/dueno.txt"
grep -q "ya hay un servidor DGR" "$R/doble.txt" && grep -q "rc 10" "$R/doble.txt" && echo "bien dos con el mismo nombre" || { echo "FALLO dos servidores:"; cat "$R/doble.txt"; fallos=$((fallos+1)); }
igual "como Forja: primer pedido con -C entre comillas" <(printf '## main\n?? k.txt\n') "$R/forja_status.txt"
igual "como Forja: ADIOS" <(echo true) "$R/forja_adios.txt"
grep -q "^true" "$R/ctrlc.txt" && echo "bien Ctrl-C lo acaba ($(cut -d' ' -f2 "$R/ctrlc.txt") s)" || { echo "FALLO Ctrl-C:"; cat "$R/ctrlc.txt"; fallos=$((fallos+1)); }
echo "tiempos:"; cat "$R/tiempos.txt" 2>/dev/null
read m0 m1 m2 < "$R/memoria.txt" || true
echo "memoria libre: al empezar $m0, tras 100+100 pedidos $m1, tras otros 200 $m2"
if [ -n "$m1" ] && [ $((m1 - m2)) -lt 20000 ]; then echo "bien memoria: no crece pedido a pedido"; else echo "FALLO memoria"; fallos=$((fallos+1)); fi
[ $fallos -eq 0 ] && echo "TODO BIEN"
exit 0
