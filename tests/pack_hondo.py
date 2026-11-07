# Escribe un pack con un blob y N deltas encadenados (cada uno sobre el anterior); da el id del último (y su texto
# en PACK.txt). Lo usa tests/fase3.sh:  python3 tests/pack_hondo.py PACK N
import hashlib, struct, sys, zlib
def cab(tipo, n):
    c = (tipo << 4) | (n & 15); n >>= 4; out = bytearray()
    while n:
        out.append(c | 0x80); c = n & 0x7F; n >>= 7
    out.append(c); return bytes(out)
def varint(n):
    out = bytearray()
    while True:
        c = n & 0x7F; n >>= 7
        if n: out.append(c | 0x80)
        else: out.append(c); return bytes(out)
def ofs(o):
    b = [o & 127]; o >>= 7
    while o:
        o -= 1; b.insert(0, 128 | (o & 127)); o >>= 7
    return bytes(b)
prof = int(sys.argv[2])
cuerpo = bytearray(); offs = []
texto = b"linea 0\n"
offs.append(12); cuerpo += cab(3, len(texto)) + zlib.compress(texto)
for i in range(1, prof + 1):
    nuevo = texto + b"linea %d\n" % i
    extra = b"linea %d\n" % i
    n = len(texto)
    d = varint(len(texto)) + varint(len(nuevo)) + bytes([0x80 | 0x10 | 0x20, n & 255, (n >> 8) & 255]) + bytes([len(extra)]) + extra
    off = 12 + len(cuerpo)
    cuerpo += cab(6, len(d)) + ofs(off - offs[-1]) + zlib.compress(d)
    offs.append(off); texto = nuevo
p = b"PACK" + struct.pack(">II", 2, prof + 1) + bytes(cuerpo)
p += hashlib.sha1(p).digest()
open(sys.argv[1], "wb").write(p)
open(sys.argv[1] + ".txt", "wb").write(texto)
print(hashlib.sha1(b"blob %d\0" % len(texto) + texto).hexdigest())
