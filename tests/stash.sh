#!/bin/bash
# commit --amend y stash (push, list, pop, apply, drop) de dashgit en FS-UAE; el git del PC lee lo que queda
# (refs/stash, su lista, los commits W e I). Acaba con "TODO BIEN".
#
#   DASH_KICKSTART=... tests/stash.sh [DASH_DIR]
set -e
dash=${1:-$HOME/Projects/FreeMEMLang}
aqui=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap '[ -n "$GUARDAR" ] && cp -r "$tmp" "$GUARDAR"; rm -rf "$tmp"' EXIT
cp -r "$HOME/.cache/dash-emu/sys31" "$tmp/sys"
chmod -R u+w "$tmp/sys"
mkdir -p "$tmp/sys/S" "$tmp/sys/P" "$tmp/sys/V"
"$dash/dash" "$aqui/src/main.dash" -o "$tmp/sys/C/dashgit"
"$dash/dash" "$aqui/tests/copia.dash" -o "$tmp/sys/C/copia"
printf 'uno\ndos\ntres\n' > "$tmp/sys/P/a.txt"
printf 'be\n' > "$tmp/sys/P/b.txt"
printf 'ce\n' > "$tmp/sys/P/c.txt"
printf 'uno\ndos cambiada\ntres\n' > "$tmp/sys/V/a2.txt"
printf 'be\nmás\n' > "$tmp/sys/V/b2.txt"
printf 'ce\notra\n' > "$tmp/sys/V/c2.txt"
{
  echo "MakeDir DH0:R"
  echo "CD DH0:P"
  echo "dashgit init >NIL:"
  echo "dashgit config user.name Prueba >NIL:"
  echo "dashgit config user.email p@p >NIL:"
  echo "dashgit add . >NIL:"
  echo "dashgit commit -m uno >NIL:"
  echo "copia DH0:V/a2.txt a.txt"
  echo "copia DH0:V/b2.txt b.txt"
  echo "dashgit add b.txt >NIL:"
  echo "dashgit stash push -m guardado >DH0:R/push.txt"
  echo "dashgit status --porcelain >DH0:R/tras_push.txt"
  echo "copia DH0:V/c2.txt c.txt"
  echo "dashgit stash >NIL:"
  echo "dashgit stash list >DH0:R/list.txt"
  echo "dashgit stash pop >DH0:R/pop.txt"
  echo "dashgit status --porcelain >DH0:R/tras_pop.txt"
  echo "dashgit commit -a -m \"con otro\" >NIL:"
  echo "dashgit commit --amend -m \"con otro, enmendado\" >DH0:R/amend.txt"
  echo "dashgit commit --amend >NIL:"
  echo "dashgit stash apply stash@{0} >DH0:R/apply.txt"
  echo "dashgit status --porcelain >DH0:R/tras_apply.txt"
  echo "dashgit stash list >DH0:R/list2.txt"
} >> "$tmp/sys/S/Startup-Extra"
cd "$dash" && python3 tools/emu_run.py --timeout ${TIEMPO:-300} --system "$tmp/sys" --keep "$tmp/disco" "$tmp/sys/C/dashgit" >/dev/null 2>&1 || true
d="$tmp/disco"
R="$d/R"
find "$d/P" -name "*.uaem" -delete
fallos=0
igual() {
  if diff "$2" "$3" >/dev/null; then echo "bien $1"; else echo "FALLO $1:"; diff "$2" "$3" | head -20; fallos=$((fallos+1)); fi
}
cd "$d/P"
igual "stash push deja el árbol limpio" /dev/null "$R/tras_push.txt"
igual "stash list" <(printf 'stash@{0}: WIP on main: %s uno\nstash@{1}: On main: guardado\n' "$(git rev-parse --short=7 HEAD~1)") "$R/list.txt"
igual "stash pop: vuelve c.txt sin preparar" <(printf ' M c.txt\n') "$R/tras_pop.txt"
igual "commit --amend: la historia" <(printf 'con otro, enmendado\nuno\n') <(git log --format=%s)
[ "$(git log -1 --format='%an|%ae|%P' | cut -d'|' -f1-2)" = "Prueba|p@p" ] && [ "$(git log -1 --format=%P)" = "$(git rev-parse HEAD~1)" ] && echo "bien amend: mismo autor y mismo padre" || { echo "FALLO amend"; git log -2 --format='%an %P'; fallos=$((fallos+1)); }
igual "stash apply sobre otro commit (fusión de tres vías)" <(printf ' M a.txt\n M b.txt\n') "$R/tras_apply.txt"
igual "el contenido aplicado" <(printf 'uno\ndos cambiada\ntres\n'; printf 'be\nmás\n'; printf 'ce\notra\n') <(cat a.txt b.txt c.txt)
igual "apply no lo quita" <(echo "stash@{0}: On main: guardado") "$R/list2.txt"
igual "el git del PC lee la lista" <(echo "stash@{0}: On main: guardado") <(git stash list)
igual "W tiene el árbol de trabajo" <(printf 'M\ta.txt\nM\tb.txt\n') <(git diff --name-status 'stash@{0}^1' 'stash@{0}')
igual "I tiene el índice" <(printf 'M\tb.txt\n') <(git diff --name-status 'stash@{0}^1' 'stash@{0}^2')
git fsck --no-dangling >/dev/null 2>&1 && echo "bien git fsck" || { echo "FALLO git fsck"; git fsck 2>&1 | head; fallos=$((fallos+1)); }
[ $fallos -eq 0 ] && echo "TODO BIEN"
exit 0
