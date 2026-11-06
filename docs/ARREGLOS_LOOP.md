# dashgit: bucle de arreglos

Los fallos que encontró la revisión del código del 2026-11-04 y lo que falta para dar dashgit por usable. Cada
vuelta del bucle hace UNA tarea, la prueba en FS-UAE, la guarda con un commit, la sube a GitHub
(`git push`, cuenta FreeMEM) y la apunta en la bitácora de abajo. Sin pausas entre vuelta y vuelta.

## Cómo se trabaja

- Compilar: `~/Projects/FreeMEMLang/dash src/main.dash -o build/dashgit`.
- Pruebas: `DASH_KICKSTART="/home/freemem/Descargas/Telegram Desktop/ks31a1200.rom" tests/<prueba>.sh`. Cada una
  acaba con "TODO BIEN". Después de cada arreglo, la prueba del caso y las que toque (fase1, fase2, diff, fase3,
  fusion, raros; fase4 es la de red).
- Cada arreglo trae su caso en una prueba (nueva o en una que ya existe), comparado con el git del PC cuando se
  pueda.
- Antes de dar algo por hecho, que pase. Si una tarea no se puede hacer, se dice por qué y se pasa a la siguiente.
- Los cambios en Dash los hace la sesión de Dash (freememlang): se le piden por SendMessage.
- Tablero común de las sesiones: `~/Projects/dash-coordinacion.md` (sesión forja-87). Poner al día la línea al
  empezar y al acabar cada tarea. El emulador, siempre bajo `flock /run/user/1000/dash-emu-red.lock`
  (por ejemplo `flock /run/user/1000/dash-emu-red.lock tests/fase2.sh`). Nada hacia fuera (GitHub, Telegram, webs)
  sin permiso del usuario en esta sesión; los `git push` de dashgit ya los tiene (bucle pedido por el usuario).
- Textos para el usuario: castellano llano y comillas rectas.
- Al acabar todas las tareas, se para el bucle y se avisa al usuario con un resumen corto.

## Tareas

Hechas en el código pero sin probar todavía (T0):

- [x] **T0.** Probar y guardar lo ya cambiado: (1) cambiar de rama o pull conserva en el índice los cambios sin
  commit de los ficheros que no cambian entre los dos commits; (2) `add` quita del índice lo que choca entre un
  fichero "a" y un cajón "a/"; (3) `commit -a` se para si no puede leer un fichero; (4, en parte) `crear_cajones` no
  da por cajón un fichero, `checkout` deja pasar un cajón que se vacía donde irá un fichero, y si falla una escritura
  a medias el índice dice lo que quedó; (6) antepasado común como `git merge-base` (fuera los que son antepasados
  de otro común); (7) en las fusiones, una última línea sin salto no es igual a la misma con salto. Casos en
  `tests/raros.sh` o una prueba nueva, y repasar todas.

Pendientes:

- [x] **T1 (8).** Cambios en el mismo segundo: al escribir el índice, las entradas con fecha igual o posterior a
  la de ahora menos 1 s van con mtime 0, para que la siguiente vez se comparen por su contenido (como hace git).
- [x] **T2 (9).** Desbordamiento en el diff: comprobar `(x + 1) * (y + 1) <= MAX_CELDAS` sin multiplicar (dividir),
  y si `buffer_alloc` da nil, el diff sencillo (todo quitado y puesto).
- [x] **T3 (10).** Etiquetas anotadas: una función que lleva una etiqueta a su commit (campo "object" del objeto
  tag), usada en checkout, branch, log, merge, diff y donde se espere un commit. `cat-file` sigue enseñando la
  etiqueta.
- [x] **T4 (11).** `branch -d` quita también la rama de `packed-refs` (y su línea "^" si la tiene).
- [x] **T5 (12).** .gitignore como git: `*` y `?` no saltan "/", `**`, clases `[...]`, "!" para volver a incluir
  (gana la última regla), y los .gitignore de los cajones. Pasar el comodín a expresión regular (`regex_match`).
  Comparar con `git check-ignore` en el PC.
- [x] **T6 (13).** Credenciales: el token solo por https, nunca por http (salvo 127.0.0.1 para las pruebas, si hace
  falta), y `DASHGIT_TOKEN` solo a un host si `DASHGIT_HOST` coincide o no hay `DASHGIT_HOST`. Documentar en el
  README cómo poner el token de GitHub.
- [x] **T7 (14).** Push y historias largas: un solo recorrido de los antepasados de las ramas remotas que ya
  tenemos (en vez de `es_antepasado` por cada commit), `es_antepasado` por anchura y sin el tope de 5000, y una rama
  nueva no manda lo que el remoto ya tiene en otras ramas.
- [x] **T8 (15).** Cadenas de deltas de hasta 300 (no 64); `user.name`/`user.email` y el mensaje, a UTF-8 solo si
  no lo son ya (`utf8_check`); `dashgit config` guarda en UTF-8; `log` enseña todos los commits por fecha, no solo
  el primer padre.
- [x] **T9 (5).** Nombres que no caben en Latin-1 ("€", japonés...) o que el disco no admite (":", más de 30
  letras en FFS) y dos rutas que solo se diferencian en mayúsculas: al sacarlos, un aviso y se saltan (sin
  pisar nada); `status` no los da por borrados.
- [x] **T10.** La prueba de red (`tests/fase4.sh`) entera: cuando la sesión de Dash arregle lo de bsdsocket.library
  tras ocho programas, o partiéndola en dos arranques del emulador.
- [ ] **T11.** Subir a GitHub de verdad con un token, solo si el usuario da un repo de pruebas y el token (no
  pedírselo dentro del bucle: se apunta como pendiente y se sigue).

## Bitácora

- 2026-11-04: bucle creado tras la revisión. T0 con el código ya cambiado.
- 2026-11-04: T0 hecho. `tests/arreglos.sh` (nueva): checkout conserva los cambios sin commit y lo añadido (también
  un fichero nuevo que no está en ningún commit, que antes se caía del índice: arreglado en esta vuelta), fichero
  "a" a cajón "a/" con add y checkout en los dos sentidos, `merge-base` (orden nueva) igual que git con dos
  antepasados comunes, y la fusión sin salto final da conflicto como git. El (3) no tiene prueba (habría que
  bloquear un fichero). Todas las pruebas locales, bien.
- 2026-11-04: T10 hecho. Con Dash main 283b11c (PR #112: el compilador directo ya cierra bsdsocket.library al
  salir), 25 programas seguidos con red van bien y `tests/fase4.sh` entera pasa (pull que fusiona y su push).
  Además: dashgit pasa a "0.1 alfa" (README, ayuda, $VER) y Forja 0.3 sale con el menú "Git (alfa)".
- 2026-11-04: T1 hecho. `indice_escribir` pone fecha 0 a las entradas de este segundo o del anterior; la prueba
  nueva de `tests/arreglos.sh` (mismo tamaño en el mismo segundo) falla sin el arreglo y pasa con él. Todas, bien.
- 2026-11-04: T2 hecho. La tabla del LCS se comprueba sin multiplicar y, si no hay memoria, el diff sencillo.
  `tests/diff.sh` lleva un diff de 47000 líneas distintas en cada lado (antes se salía de 32 bits): bien.
- 2026-11-04: T3 hecho. `resolver_commit` lleva una etiqueta anotada a su commit; lo usan checkout, branch, log,
  merge y merge-base (cat-file sigue con `resolver`). `tests/fase3.sh` lleva una etiqueta anotada hecha en el PC:
  log, branch desde ella, checkout (HEAD suelto) y status limpio. Bien.
- 2026-11-06: T4 hecho. `ref_borrar` (repo.dash) quita el fichero suelto y la línea de `packed-refs` con su "^";
  `branch -d` la usa. `tests/fase3.sh` borra una rama que solo está en packed-refs y otra que está en los dos
  sitios, y comprueba con git que no quedan y que la etiqueta sigue. Bien.
- 2026-11-06: T5 hecho. El .gitignore va como git (indice.dash): cada regla pasa a expresión regular ("*" y "?"
  sin saltar "/", "**/", "/**", "/**/", clases [a-z] [!a] [[:alpha:]], "\" para tomar un carácter tal cual) o a
  comparación directa si no tiene comodines; "!" vuelve a incluir (gana la última regla que encaja); un cajón
  ignorado ignora todo lo de dentro; se leen los .gitignore de cada cajón (el más hondo manda) y después
  .git/info/exclude; con core.ignorecase sin mirar mayúsculas; un .gitignore en Latin-1 se pasa a UTF-8. Orden
  nueva `dashgit check-ignore ruta...`, como la de git. `tests/arreglos.sh` lleva un árbol con 45 ficheros y 21
  reglas (tests/arbol_ignorar.sh): check-ignore de todos y `add .` dan lo mismo que el git del PC. Bien.
- 2026-11-06: T6 hecho. `autorizacion` (red.dash) recibe la dirección entera: por http no manda el token (salvo a
  127.0.0.1, que no sale del ordenador; lo usan las pruebas); DASHGIT_TOKEN y DASHGIT_USUARIO solo valen para el
  host de DASHGIT_HOST si está; el fichero de credenciales compara el host sin mirar mayúsculas. Si el servidor pide
  token por http, el aviso dice que use https. El README explica cómo hacer el token de GitHub y ponerlo.
  `tests/fase4.sh`: el servidor apunta el Host y si llega Authorization; con el token puesto, a 127.0.0.1 sí va, a
  127.0.0.2 por http no, y con DASHGIT_HOST de otro host tampoco. Bien. (Por https no se ha probado: T11.)
- 2026-11-06: T7 hecho. `push` recorre una sola vez los antepasados de todas las ramas y etiquetas del remoto que
  tenemos (`marcar_antepasados`, fusion.dash), y de ahí saca los commits nuevos; de árboles y blobs solo manda lo que
  no está en los commits del remoto de los que salen. Una rama nueva ya no manda lo que el remoto tiene en otras.
  `es_antepasado` va por anchura y sin el tope de 5000. `tests/fase4.sh`: push de una rama nueva (490 bytes; antes
  mandaba toda la historia) y `tests/fase3.sh`: `merge` de una rama vieja en una historia de 6001 commits da "al
  día" (antes, con el tope, no la encontraba). Bien.
- 2026-11-06: T8 hecho. Los packs admiten cadenas de hasta 300 deltas (antes 64). La firma, el mensaje y el mensaje
  de una fusión pasan a UTF-8 solo si no lo son ya (`a_utf8`, util.dash); `dashgit config` guarda en UTF-8 y al
  enseñar un valor lo pasa a Latin-1. `log` enseña todos los commits (de todos los padres) del más nuevo al más
  viejo por la fecha del committer, como git log (y la línea "Merge:" en las fusiones). Pruebas:
  `tests/fase3.sh` lee un blob al final de una cadena de 300 deltas (pack hecho con tests/pack_hondo.py) y
  `tests/arreglos.sh` comprueba con git el nombre puesto en Latin-1, un mensaje que ya llega en UTF-8, la config en
  UTF-8 y `log --oneline` de una historia con fusiones, igual que git. Bien. Nota: emu_run.py escribe el
  Startup-Sequence en UTF-8, así que lo de Latin-1 va por variables de ENV:.
- 2026-11-06: T9 hecho. `fuera_del_disco` (indice.dash) da las rutas que no pueden estar en el disco del Amiga: las
  que no caben en Latin-1, las que llevan ":", un nombre de más de 30 letras si el disco no los admite (se prueba
  una vez creando un fichero de nombre largo en .git) y las que solo cambian en mayúsculas de otra que va antes
  (también un cajón que choca así con un fichero). Al sacar un commit se saltan con un aviso, sin escribir ni
  borrar nada en su lugar, y se quedan en el índice; status no las da por borradas, y add y commit -a no las quitan.
  `tests/raros.sh` lleva una rama hecha en el PC con "€", japonés, ":", "readme" junto a "README" y un cajón
  "OTRO.TXT/" junto a "otro.txt": checkout salta los 5, status limpio, commit -a los conserva y volver a main no
  borra README. Bien. El caso de más de 30 letras en FFS no se ha probado: el disco del emulador es un cajón del
  PC y admite nombres largos (allí el nombre largo se escribe bien).
- 2026-11-06: con T4-T9, todas las pruebas acaban en "TODO BIEN": fase1, fase2, diff, fase3, fusion, raros, arreglos
  y fase4. Quedan T11 (token de GitHub de verdad) y probar en FFS los nombres de más de 30 letras.
