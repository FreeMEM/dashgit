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
- [ ] **T2 (9).** Desbordamiento en el diff: comprobar `(x + 1) * (y + 1) <= MAX_CELDAS` sin multiplicar (dividir),
  y si `buffer_alloc` da nil, el diff sencillo (todo quitado y puesto).
- [ ] **T3 (10).** Etiquetas anotadas: una función que lleva una etiqueta a su commit (campo "object" del objeto
  tag), usada en checkout, branch, log, merge, diff y donde se espere un commit. `cat-file` sigue enseñando la
  etiqueta.
- [ ] **T4 (11).** `branch -d` quita también la rama de `packed-refs` (y su línea "^" si la tiene).
- [ ] **T5 (12).** .gitignore como git: `*` y `?` no saltan "/", `**`, clases `[...]`, "!" para volver a incluir
  (gana la última regla), y los .gitignore de los cajones. Pasar el comodín a expresión regular (`regex_match`).
  Comparar con `git check-ignore` en el PC.
- [ ] **T6 (13).** Credenciales: el token solo por https, nunca por http (salvo 127.0.0.1 para las pruebas, si hace
  falta), y `DASHGIT_TOKEN` solo a un host si `DASHGIT_HOST` coincide o no hay `DASHGIT_HOST`. Documentar en el
  README cómo poner el token de GitHub.
- [ ] **T7 (14).** Push y historias largas: un solo recorrido de los antepasados de las ramas remotas que ya
  tenemos (en vez de `es_antepasado` por cada commit), `es_antepasado` por anchura y sin el tope de 5000, y una rama
  nueva no manda lo que el remoto ya tiene en otras ramas.
- [ ] **T8 (15).** Cadenas de deltas de hasta 300 (no 64); `user.name`/`user.email` y el mensaje, a UTF-8 solo si
  no lo son ya (`utf8_check`); `dashgit config` guarda en UTF-8; `log` enseña todos los commits por fecha, no solo
  el primer padre.
- [ ] **T9 (5).** Nombres que no caben en Latin-1 ("€", japonés...) o que el disco no admite (":", más de 30
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
