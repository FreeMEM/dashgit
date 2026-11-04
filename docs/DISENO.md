# dashgit: diseño, plan y bitácora

Un cliente de git para AmigaOS 3.x en 68k, escrito en [Dash](https://github.com/FreeMEM/dash). Licencia GPLv2, la
misma de git. Decidido por el usuario el 2026-11-04, tras descartar am-git (sin fuentes ni licencia).

## Decisiones

- **El mismo formato que git.** El cajón `.git` es el de git: objetos sueltos con zlib, índice versión 2, packs
  versión 2 con su `.idx`, `refs/` y `packed-refs`. Un repositorio hecho con dashgit se abre con git en el PC, y al
  revés. Las pruebas lo comprueban con el git del PC.
- **Una orden del Shell.** `dashgit <orden> [argumentos]`, con los nombres de git: `init`, `add`, `commit`...
  Forja la usará desde su menú Git, como ya usa `dash`, y mostrará lo que escriba en su panel de salida.
- **Lo que necesita de Dash** (en Dash main desde el PR #108): `sha1` y `sha1_new`/`sha1_add`/`sha1_bytes`,
  `inflate_used()` (los bytes de entrada que usó el último inflate, para leer packs), `adler32` (zlib con
  cabecera), `program_exit` (código de retorno 10 si algo falla) y `locale_gmt_offset` (la zona de las fechas).
- **Nombres de ficheros.** Git guarda bytes y el PC usa UTF-8. En el disco del Amiga van en Latin-1. dashgit
  convierte al leer y al escribir el árbol de trabajo (`utf8_to_latin1`, `latin1_to_utf8`).
- **Mayúsculas.** El sistema de ficheros del Amiga no las distingue. Dos rutas que solo se diferencian en eso son
  un error al sacar los ficheros (`checkout`), no se pisan.
- **Permisos.** Los ficheros nuevos van como `100644`. Los que ya están en el índice conservan su modo (un
  `100755` del PC sigue igual). Los enlaces simbólicos (`120000`) y los submódulos se saltan con un aviso.
- **Saltos de línea.** No se tocan: el Amiga usa LF, como git.
- **Memoria.** Cada objeto se carga entero. Los packs se leen con `file_seek` desde su `.idx`, sin cargarlos
  enteros. Un objeto más grande que la memoria libre da un error claro.
- **Fechas.** `time_unix()` es la hora local del Amiga; se le resta la zona de `locale_gmt_offset()` (o la de
  `dashgit config dashgit.zona +0100`) para guardar la hora en UTC con su zona, como git.
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
- 2026-11-04: fase 1 hecha (`tests/fase1.sh`: init, hash-object, cat-file, config; el git del PC lee lo que escribe
  el Amiga). Fase 2 casi entera (`tests/fase2.sh`): add (con .gitignore sencillo), rm, status (también -s), commit
  (-a, -m), log (--oneline, -n), branch (-d), checkout (rama, -b, -- fichero), y el git del PC da por buenos los
  commits, el índice y los árboles. `diff` y `diff --cached` (`tests/diff.sh`) dan lo mismo que el git del PC,
  salvo el nombre de la función que git pone tras los `@@`. En el emulador, FS-UAE deja ficheros `.uaem` junto a los del
  disco: las pruebas los borran antes de pasar el git del PC.
- Dash: las funciones que empiezan por `_` no se ven desde otro módulo; `for i in (0..n - 1)` con n = 0 cuenta
  hacia abajo (0, -1), así que los bucles que pueden estar vacíos van con `while`.
- 2026-11-04: con los builtins de Dash (PR #108) fuera el SHA-1 en Dash puro; zona de Locale y código de retorno
  10 cuando una orden falla. Las tres pruebas, bien.
- 2026-11-04: fase 3 (`tests/fase3.sh`): packs v2 con su `.idx` (búsqueda por la tabla de 256, offsets de 64 bits)
  y deltas `ofs` y `ref`. Lo comprimido de cada objeto se lee de una vez: como mucho su tamaño + 1/16 + 64 bytes,
  e inflate ignora lo que sobra. Un clon del PC con `git gc --aggressive` (11 objetos con delta) da en el Amiga el
  mismo log y los mismos blobs; status limpio, checkout de otra rama y commit encima, y el git del PC lo da por
  bueno. Pendiente: ids abreviados que solo están en packs, y una caché de bases para cadenas de deltas largas.
  FS-UAE no abre los ficheros de solo lectura del PC (git deja así los packs): la prueba les quita esa marca.
- 2026-11-04: fase 4 (`tests/fase4.sh`, contra `tests/servidor_git.py`, git http-backend en el PC; también con
  `chunked=1`): clone (ramas, etiquetas, HEAD del remoto), push (un pack sin deltas, report-status), fetch y pull
  con avance rápido. El índice del pack recibido se hace como `git index-pack` (con `inflate_used` y crc32).
  Clon de verdad desde GitHub por HTTPS con AmiSSL en el emulador: FreeMEM/inferencia (373 objetos, 181 KB de pack,
  65 ficheros) en unos 3 minutos de emulador a toda velocidad, y el git del PC lo da por bueno (fsck, status
  limpio, árbol idéntico). Sin probar: push a GitHub con token, y la velocidad en un A1200 de verdad.
  Pendiente: fusionar (pull sin avance rápido), la respuesta entera va a memoria (repos grandes), deltas al subir.
- 2026-11-04: `-C cajón` (como en git). Fase 5 en la rama `git` de Forja: menú Git (estado, diferencias, historial,
  añadir, confirmar con mensaje, pull, push) y `GIT`/`SALIDA` por ARexx; su `tests/git.sh` hace init, commit,
  diff, log y push a un servidor del PC desde Forja. Pendiente: marcar en el panel del proyecto los ficheros
  cambiados.
- 2026-11-04: fusiones (`tests/fusion.sh`): `merge rama` (avance rápido, o de tres vías con el antepasado común más
  cercano), por líneas; lo que choca va entre marcas `<<<<<<<`/`=======`/`>>>>>>>` y en el índice con las etapas
  1-3, como git. `status` dice "sin fusionar" (UU), `add` lo da por resuelto, `commit` sin -m usa MERGE_MSG y pone
  los dos padres; `merge --abort`. El árbol fusionado es el mismo que da git. `pull` fusiona cuando los dos lados
  tienen commits. En FS-UAE, desde el noveno programa con red de un mismo arranque ya no se abre bsdsocket.library
  (pasado a la sesión de Dash): por eso la parte nueva de `tests/fase4.sh` (pull que fusiona y su push) falla allí.
