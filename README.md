# QuestBuffer

Addon de WoW Forever para compartir varias misiones con el grupo sin que fallen.

El servidor solo permite **una** misión compartida pendiente por jugador; la segunda recibe "X está ocupado". QuestBuffer arregla esto en los dos lados:

- **Quien comparte:** al pulsar *Compartir* en varias misiones, se ponen en cola y se envía la siguiente cuando todos los destinatarios han aceptado o rechazado la anterior. 
- **Compartir en lote:** `/qb` abre una ventana con tus misiones compartibles; marcas las que quieras y pulsas *Compartir selección*. Van a la misma cola. `/qb clear` vacía la cola. `/qb debug` imprime los mensajes de sistema mientras la cola espera (para diagnosticar si no avanza).
- **Quien recibe:** aparece un panel con **Aceptar todas** / **Borrar todas**, que responde también al resto del lote (15 s sin misiones nuevas y vuelve al modo normal; la X lo cancela).

Compatible con [Dialogue UI](https://www.curseforge.com/wow/addons/dialogueui): la misión compartida sigue mostrándose en su ventana; el panel de QuestBuffer va aparte (arrastrable, por encima de la ventana de Dialogue UI) y responde con `AcceptQuest`/`DeclineQuest`, que es lo que usan sus botones.

## Instalación

Copia la carpeta a `World of Warcraft/_forever_/Interface/AddOns/QuestBuffer` (el nombre de la carpeta debe ser `QuestBuffer`).

## Estado

v0.1.0, sin probar en el juego. Ver `QuestBuffer.lua` para los supuestos (cadenas `ERR_QUEST_PUSH_*`, `QuestLogPushQuest`, unit `questnpc`).

Pruebas de la lógica con el API de WoW simulado: `lua tests/test.lua` (desde la raíz del repo).
