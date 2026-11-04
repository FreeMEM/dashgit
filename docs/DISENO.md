# dashgit: diseño, plan y bitácora

Un cliente de git para AmigaOS 3.x en 68k, escrito en [Dash](https://github.com/FreeMEM/dash). Licencia GPLv2, la
misma de git. Decidido por el usuario el 2026-11-04, tras descartar am-git (sin fuentes ni licencia).

## Decisiones

- **El mismo formato que git.** El cajón `.git` es el de git: objetos sueltos con zlib, índice versión 2, packs
  versión 2 con su `.idx`, `refs/` y `packed-refs`. Un repositorio hecho con dashgit se abre con git en el PC, y al
  revés. Las pruebas lo comprueban con el git del PC.
- **Una orden del Shell.** `dashgit <orden> [argumentos]`, con los nombres de git: `init`, `add`, `commit`...
  Forja la usará desde su menú Git, como ya usa `dash`, y mostrará lo que escriba en su panel de salida.
- **Lo que necesita de Dash** (rama `sha1` de Dash, en pruebas): `sha1_new`/`sha1_add`/`sha1_bytes`/`sha1_hex` y
  `sha1(buffer, n)`, `inflate_used()` (los bytes de entrada que usó el último inflate, para leer packs) y
  `adler32` (para escribir zlib con cabecera). El SHA-1 en Dash puro (`src/sha1.dash`) funciona, pero va a unos
  8 KB/s en el emulador: solo queda de reserva.
- **Nombres de ficheros.** Git guarda bytes y el PC usa UTF-8. En el disco del Amiga van en Latin-1. dashgit
  convierte al leer y al escribir el árbol de trabajo (`utf8_to_latin1`, `latin1_to_utf8`).
- **Mayúsculas.** El sistema de ficheros del Amiga no las distingue. Dos rutas que solo se diferencian en eso son
  un error al sacar los ficheros (`checkout`), no se pisan.
- **Permisos.** Los ficheros nuevos van como `100644`. Los que ya están en el índice conservan su modo (un
  `100755` del PC sigue igual). Los enlaces simbólicos (`120000`) y los submódulos se saltan con un aviso.
- **Saltos de línea.** No se tocan: el Amiga usa LF, como git.
- **Memoria.** Cada objeto se carga entero. Los packs se leen con `file_seek` desde su `.idx`, sin cargarlos
  enteros. Un objeto más grande que la memoria libre da un error claro.
- **Fechas.** `time_unix()` y la zona de `ENV:TZ` si está; si no, `+0000`.
- **Red.** HTTP inteligente de git (`info/refs`, `git-upload-pack`, `git-receive-pack`), protocolo v0/v1, sobre
  los `net_*` y `tls_*` de Dash con AmiSSL. Sin ssh. Credenciales: un token en `ENVARC:dashgit/credenciales`
  (formato netrc), o `DASHGIT_USUARIO` y `DASHGIT_TOKEN`.
- **Textos.** En castellano y en inglés, con catálogo, como Forja.

## Fases

1. **Objetos.** `init`, `hash-object [-w]`, `cat-file -t|-s|-p`. Objetos sueltos con zlib.
2. **Índice y commits.** `add`, `rm`, `status`, `commit -m`, `log`, `branch`, `checkout`, `diff` (por líneas,
   sencillo), `config user.name/user.email`.
3. **Packs.** Leer packs y `.idx` (objetos con delta `ofs` y `ref`), `packed-refs`. Con esto ya se abre un repo
   clonado en el PC.
4. **Red.** `clone`, `fetch`, `pull` (solo avance rápido) y `push` (un pack sin deltas).
5. **Forja.** Menú Git: estado, añadir, confirmar, subir, traer, historial y diferencias. Marcas en el panel del
   proyecto para los ficheros cambiados.

## Pruebas

`tests/*.dash` se ejecutan en FS-UAE con `tools/emu_run.py` de Dash:

    DASH_KICKSTART=... python3 ~/Projects/FreeMEMLang/tools/emu_run.py --dash2 --follow tests/sha1.dash

Cada prueba acaba con "TODO BIEN". Las de formato comparan con lo que hace el git del PC en el mismo cajón.

## Bitácora

- 2026-11-04: repo creado (GPLv2). `src/sha1.dash`: SHA-1 en Dash puro, bien con los vectores de prueba
  (vacío, "abc", 448 bits, 20000 "a"); 20000 bytes en 2,3 s en el emulador. Un texto de Dash no puede llevar
  bytes 0: las cabeceras de los objetos (`blob 5\0`) se arman en búferes.
