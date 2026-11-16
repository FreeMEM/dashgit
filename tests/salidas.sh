#!/bin/bash
# Las salidas para máquinas de dashgit en FS-UAE (status --porcelain -b, branch --show-current, diff --name-status,
# --numstat, -U0 y --rangos, diff entre commits, log --format y log -- fichero, show, reset y restore --staged),
# comparadas con lo que da el git del PC. Acaba con "TODO BIEN".
#
#   DASH_KICKSTART=... tests/salidas.sh [DASH_DIR]
set -e
dash=${1:-$HOME/Projects/FreeMEMLang}
aqui=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap '[ -n "$GUARDAR" ] && cp -r "$tmp" "$GUARDAR"; rm -rf "$tmp"' EXIT
cp -r "$HOME/.cache/dash-emu/sys31" "$tmp/sys"
chmod -R u+w "$tmp/sys"
mkdir -p "$tmp/sys/S" "$tmp/sys/P/sub" "$tmp/sys/V"
"$dash/dash" "$aqui/src/main.dash" -o "$tmp/sys/C/dashgit"
"$dash/dash" "$aqui/tests/copia.dash" -o "$tmp/sys/C/copia"
"$dash/dash" "$aqui/tests/borra.dash" -o "$tmp/sys/C/borra"
python3 - "$tmp/sys" <<'PY'
import sys
d = sys.argv[1]
a = [f"línea {i}" for i in range(1, 41)]
w = lambda p, t: open(p, "w", encoding="latin-1").write(t)
w(f"{d}/P/a.txt", "\n".join(a) + "\n")
b = list(a); b[2] = "línea 3 cambiada"; del b[9]; b.insert(20, "una nueva"); b.insert(21, "y otra"); b[30] = "otra cambiada"; b.append("al final")
w(f"{d}/V/a2.txt", "\n".join(b) + "\n")
c = list(b); c[0] = "primera distinta"
w(f"{d}/V/a3.txt", "\n".join(c) + "\n")
w(f"{d}/P/b.txt", "be\n")
w(f"{d}/V/b2.txt", "be\ndos\n")
w(f"{d}/V/b3.txt", "be\ndos\ntres\n")
w(f"{d}/V/b4.txt", "cuatro\n")
w(f"{d}/P/sub/c.txt", "ce\n")
w(f"{d}/V/n.txt", "nuevo\n")
w(f"{d}/V/n2.txt", "nuevo dos\n")
w(f"{d}/V/u.txt", "sin seguir\n")
PY
F='"--format=%H|%h|%P|%p|%an|%ae|%at|%cn|%ce|%ct|%s|%T|%t"'
{
  echo "MakeDir DH0:R"
  echo "CD DH0:P"
  echo "dashgit init >NIL:"
  echo "dashgit config user.name Prueba >NIL:"
  echo "dashgit config user.email p@p >NIL:"
  echo "dashgit add . >NIL:"
  echo "dashgit diff --rangos HEAD -- b.txt >DH0:R/rangos_vacio.txt"
  echo "dashgit commit -m uno >NIL:"
  echo "dashgit status --porcelain -b >DH0:R/st_limpio.txt"
  echo "copia DH0:V/a2.txt a.txt"
  echo "copia DH0:V/b2.txt b.txt"
  echo "dashgit add b.txt >NIL:"
  echo "copia DH0:V/b3.txt b.txt"
  echo "copia DH0:V/n.txt n.txt"
  echo "dashgit add -- n.txt >DH0:R/add_guiones.txt"
  echo "copia DH0:V/u.txt u.txt"
  echo "borra sub/c.txt"
  echo "dashgit status --porcelain -b >DH0:R/st.txt"
  echo "dashgit status -s >DH0:R/st_s.txt"
  echo "dashgit branch --show-current >DH0:R/rama.txt"
  echo "dashgit diff --name-status >DH0:R/ns.txt"
  echo "dashgit diff --name-only >DH0:R/no.txt"
  echo "dashgit diff --cached --name-status >DH0:R/ns_cached.txt"
  echo "dashgit diff HEAD --name-status >DH0:R/ns_head.txt"
  echo "dashgit diff HEAD --numstat >DH0:R/num_head.txt"
  echo "dashgit diff -U0 HEAD -- a.txt >DH0:R/u0.txt"
  echo "dashgit diff --rangos HEAD a.txt >DH0:R/rangos.txt"
  echo "dashgit diff --rangos HEAD -- n.txt >DH0:R/rangos_n.txt"
  echo "dashgit diff HEAD >DH0:R/head.txt"
  echo "dashgit add -A >NIL:"
  echo "dashgit commit -m \"dos: cambios\" >NIL:"
  echo "copia DH0:V/a3.txt a.txt"
  echo "dashgit commit -a -m tres >NIL:"
  echo "dashgit branch otra >NIL:"
  echo "dashgit log $F >DH0:R/log.txt"
  echo "dashgit log --format=%s -- a.txt >DH0:R/log_a.txt"
  echo "dashgit log --oneline b.txt >DH0:R/log_b.txt"
  echo "dashgit log --format=%s -n 1 -- sub >DH0:R/log_sub.txt"
  echo "dashgit show --name-status --format=%H HEAD~1 >DH0:R/show_ns.txt"
  echo "dashgit show HEAD~1 >DH0:R/show.txt"
  echo "dashgit show HEAD^^:a.txt >DH0:R/show_a.txt"
  echo "dashgit diff HEAD~2 HEAD >DH0:R/d12.txt"
  echo "dashgit diff HEAD~2..HEAD --name-status >DH0:R/d12ns.txt"
  echo "dashgit branch >DH0:R/ramas.txt"
  echo "copia DH0:V/b4.txt b.txt"
  echo "dashgit add b.txt >NIL:"
  echo "dashgit reset -- b.txt >NIL:"
  echo "copia DH0:V/n2.txt nuevo2.txt"
  echo "dashgit add nuevo2.txt >NIL:"
  echo "dashgit restore --staged nuevo2.txt >NIL:"
  echo "dashgit status --porcelain >DH0:R/st_reset.txt"
  echo "dashgit diff --cached >DH0:R/cached_reset.txt"
} >> "$tmp/sys/S/Startup-Extra"
cd "$dash" && python3 tools/emu_run.py --timeout ${TIEMPO:-300} --system "$tmp/sys" --keep "$tmp/disco" "$tmp/sys/C/dashgit" >/dev/null 2>&1 || true
d="$tmp/disco"
R="$d/R"
find "$d/P" -name "*.uaem" -delete
fallos=0
igual() {  # igual nombre esperado obtenido
  if diff "$2" "$3" >/dev/null; then echo "bien $1"; else echo "FALLO $1:"; diff "$2" "$3" | head -20; fallos=$((fallos+1)); fi
}
limpia() { grep -av '^index ' "$1" | sed 's/^\(@@ [^@]* @@\).*/\1/'; }
# el mismo camino con el git del PC, en otro cajón, hasta el primer punto de comparación
pc="$tmp/pc"
mkdir -p "$pc/sub"
cp "$tmp/sys/P/a.txt" "$tmp/sys/P/b.txt" "$pc/"; cp "$tmp/sys/P/sub/c.txt" "$pc/sub/"
V="$tmp/sys/V"
( cd "$pc" && git init -q -b main && git add . && git -c user.name=P -c user.email=p@p commit -qm uno
  git status --porcelain -b > "$tmp/e_st_limpio.txt"
  cp "$V/a2.txt" a.txt; cp "$V/b2.txt" b.txt; git add b.txt; cp "$V/b3.txt" b.txt
  cp "$V/n.txt" n.txt; git add n.txt; cp "$V/u.txt" u.txt; rm sub/c.txt
  git status --porcelain -b -uall > "$tmp/e_st.txt"
  git status -s -uall > "$tmp/e_st_s.txt"
  git diff --name-status > "$tmp/e_ns.txt"
  git diff --name-only > "$tmp/e_no.txt"
  git diff --cached --name-status > "$tmp/e_ns_cached.txt"
  git diff HEAD --name-status > "$tmp/e_ns_head.txt"
  git diff HEAD --numstat > "$tmp/e_num_head.txt"
  git diff -U0 HEAD -- a.txt > "$tmp/e_u0.txt"
  git diff HEAD > "$tmp/e_head.txt"
)
igual "status --porcelain -b limpio" "$tmp/e_st_limpio.txt" "$R/st_limpio.txt"
igual "status --porcelain -b" "$tmp/e_st.txt" "$R/st.txt"
igual "status -s (MM en una línea)" "$tmp/e_st_s.txt" "$R/st_s.txt"
igual "add -- fichero, sin avisos" /dev/null "$R/add_guiones.txt"
igual "branch --show-current" <(echo main) "$R/rama.txt"
igual "diff --name-status" "$tmp/e_ns.txt" "$R/ns.txt"
igual "diff --name-only" "$tmp/e_no.txt" "$R/no.txt"
igual "diff --cached --name-status" "$tmp/e_ns_cached.txt" "$R/ns_cached.txt"
igual "diff HEAD --name-status" "$tmp/e_ns_head.txt" "$R/ns_head.txt"
igual "diff HEAD --numstat" "$tmp/e_num_head.txt" "$R/num_head.txt"
igual "diff -U0 HEAD -- a.txt" <(limpia "$tmp/e_u0.txt") <(limpia "$R/u0.txt")
igual "diff HEAD" <(limpia "$tmp/e_head.txt") <(limpia "$R/head.txt")
# los rangos que salen de los @@ de git diff -U0
python3 - "$tmp/e_u0.txt" "a.txt" > "$tmp/e_rangos.txt" <<'PY'
import re, sys
print("F " + sys.argv[2])
for l in open(sys.argv[1], encoding="latin-1"):
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
igual "diff --rangos HEAD a.txt" "$tmp/e_rangos.txt" "$R/rangos.txt"
igual "diff --rangos HEAD sin commits" <(printf 'F b.txt\nA 1 1\n') "$R/rangos_vacio.txt"
igual "diff --rangos de un fichero nuevo" <(printf 'F n.txt\nA 1 1\n') "$R/rangos_n.txt"
# lo demás, con el git del PC sobre el mismo repositorio del Amiga
cd "$d/P"
G="git -c core.quotepath=off"
igual "log --format" <($G log "--format=%H|%h|%P|%p|%an|%ae|%at|%cn|%ce|%ct|%s|%T|%t") "$R/log.txt"
igual "log -- a.txt" <($G log --format=%s -- a.txt) "$R/log_a.txt"
igual "log b.txt (sin --)" <($G log --oneline -- b.txt) "$R/log_b.txt"
igual "log -n 1 -- sub" <($G log --format=%s -n 1 -- sub) "$R/log_sub.txt"
igual "show --name-status --format=%H" <($G show --name-status --format=%H HEAD~1) "$R/show_ns.txt"
igual "show (los cambios)" <($G show HEAD~1 | sed -n '/^diff --git/,$p' | grep -av '^index ' | sed 's/^\(@@ [^@]* @@\).*/\1/') <(sed -n '/^diff --git/,$p' "$R/show.txt" | grep -av '^index ' | sed 's/^\(@@ [^@]* @@\).*/\1/')
igual "show HEAD^^:a.txt" <($G show HEAD~2:a.txt) "$R/show_a.txt"
igual "diff HEAD~2 HEAD" <($G diff HEAD~2 HEAD | limpia /dev/stdin) <(limpia "$R/d12.txt")
igual "diff HEAD~2..HEAD --name-status" <($G diff HEAD~2..HEAD --name-status) "$R/d12ns.txt"
igual "branch" <(printf '* main\n  otra\n') "$R/ramas.txt"
igual "reset -- b.txt y restore --staged" <($G status --porcelain -uall) "$R/st_reset.txt"
[ ! -s "$R/cached_reset.txt" ] && [ -z "$($G diff --cached)" ] && echo "bien reset: nada preparado" || { echo "FALLO reset: queda algo preparado"; cat "$R/cached_reset.txt"; fallos=$((fallos+1)); }
[ $fallos -eq 0 ] && echo "TODO BIEN"
exit 0
