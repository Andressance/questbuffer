# QuestBuffer

Addon de WoW (Retail) para compartir varias misiones con el grupo sin que fallen.

El servidor solo permite **una** misión compartida pendiente por jugador; la segunda recibe "X está ocupado". QuestBuffer arregla esto en los dos lados:

- **Quien comparte:** al pulsar *Compartir* en varias misiones, se ponen en cola y se envía la siguiente cuando todos los destinatarios han aceptado o rechazado la anterior. `/qb` vacía la cola.
- **Quien recibe:** aparece un panel con **Aceptar todas** / **Borrar todas**, que responde también al resto del lote (15 s sin misiones nuevas y vuelve al modo normal; la X lo cancela).

Compatible con [Dialogue UI](https://www.curseforge.com/wow/addons/dialogueui): solo escucha eventos y llama a `AcceptQuest`/`DeclineQuest`, no toca ninguna ventana de misión.

## Instalación

Copia la carpeta a `World of Warcraft/_retail_/Interface/AddOns/QuestBuffer` (el nombre de la carpeta debe ser `QuestBuffer`).

## Estado

v0.1.0, sin probar en el juego. Ver `QuestBuffer.lua` para los supuestos (cadenas `ERR_QUEST_PUSH_*`, `QuestLogPushQuest`, unit `questnpc`).
