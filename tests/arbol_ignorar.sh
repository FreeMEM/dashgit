# Crea en el cajón actual el árbol de prueba de .gitignore (lo usa tests/arreglos.sh)
mk() { mkdir -p "$(dirname "$1")"; echo "$1" > "$1"; }
cat > .gitignore <<'G'
# comentario
*.o
!importante.o
/raiz.txt
build/
!build/guarda
doc/**/*.tmp
**/cache
[abc]x.dat
[!a-c]y.dat
log?.txt
*.BAK
\#almoh
sub/fijo.txt
hondo/**
ent*/
tmp/*
!tmp/guarda
!b.excl
ñ*.txt
a/**/z
G
mkdir -p src
printf '!b.o\n*.txt\n!vale.txt\n' > src/.gitignore
for f in a.o importante.o src/b.o src/c.o src/importante.o raiz.txt src/raiz.txt src/vale.txt build/x build/guarda \
  src/build/y doc/x.tmp doc/a/b/y.tmp doc/z.txt otro/doc/w.tmp cache/c1 src/cache/c2 src/cachex ax.dat dx.dat \
  ay.dat dy.dat log1.txt log12.txt logs/log1.txt x.bak '#almoh' sub/fijo.txt otro/sub/fijo.txt hondo/q/r.txt \
  hondo/s entrada/f.txt entero tmp/guarda tmp/otro a.excl b.excl ñandu.txt nandu.txt a/z a/b/c/z a/zz README; do
  mk "$f"
done
