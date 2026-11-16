# QuestBuffer

<img src="logo.png" alt="QuestBuffer" width="200">

Addon de WoW (Retail, Classic y Forever) para compartir varias misiones con el grupo sin que fallen.

El servidor solo permite **una** misión compartida pendiente por jugador; la segunda recibe "X está ocupado". QuestBuffer arregla esto en los dos lados:

- **Quien comparte:** al pulsar *Compartir* en varias misiones, se ponen en cola y se envía la siguiente cuando todos los destinatarios han aceptado o rechazado la anterior. 
- **Compartir en lote:** `/qb` abre una ventana con tu diario agrupado por zona/categoría. Cada misión muestra nivel (con el color de dificultad), etiqueta (mazmorra, élite...) y si está completada; con [Questie](https://www.curseforge.com/wow/addons/questie) cargado, también dónde empieza (NPC y zona). Marca misiones con su casilla (o una zona entera con la casilla de la cabecera), o usa *Todas*, *Ninguna* o *Mazmorras*; luego *Compartir marcadas*, *Compartir todas* o *Compartir zona* en la cabecera. Todos los botones explican lo que hacen al pasar el ratón. Abajo, una línea de estado dice qué misión se está compartiendo, cuántas quedan y a quién se espera, con un botón para cancelar la cola.
- **Botón del minimapa:** un círculo con el logo abre la ventana (arrastrable alrededor del minimapa). Se llama `QuestBufferMinimapButton`, así que addons que recogen botones como Minimap Button Button lo absorben solos. `/qb minimap` lo oculta o lo muestra.
- **Comandos:** `/qb clear` vacía la cola. `/qb debug` imprime los mensajes de sistema mientras la cola espera (para diagnosticar si no avanza).
- **Quien recibe:** aparece un panel con **Aceptar todas** / **Rechazar todas**, que responde también al resto del lote (15 s sin misiones nuevas y vuelve al modo normal; la X lo cancela).

Compatible con [Dialogue UI](https://www.curseforge.com/wow/addons/dialogueui): la misión compartida sigue mostrándose en su ventana; el panel de QuestBuffer va aparte (arrastrable, por encima de la ventana de Dialogue UI) y responde con `AcceptQuest`/`DeclineQuest`, que es lo que usan sus botones.

## Instalación

Copia la carpeta a `Interface/AddOns/QuestBuffer` de tu versión del juego (`_retail_`, `_classic_`, `_classic_era_` o `_forever_`). El nombre de la carpeta debe ser `QuestBuffer`.

## Estado

v0.3.1. Probado en el juego en WoW Forever; Retail y Classic usan el mismo código con la API que corresponde a cada cliente, pero aún no se han probado en el juego. Limitación conocida: las misiones bajo una zona plegada en el diario no salen en la ventana; despliega la zona. Ver `QuestBuffer.lua` para los supuestos de la cola (cadenas `ERR_QUEST_PUSH_*`).

Pruebas de la lógica con el API de WoW simulado: `lua tests/test.lua` (desde la raíz del repo).

## Licencia

MIT, ver [LICENSE](LICENSE).
