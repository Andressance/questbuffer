# QuestBuffer

**Share all your quests with your group at once, without the "X is busy" error.**

WoW only lets a player have one shared quest waiting at a time. Share three quests in a row and your friends get the first one; the rest fail with "is busy". QuestBuffer queues them and sends the next one as soon as everyone has accepted or declined the previous one.

Works on **Retail, Classic (Era, TBC, MoP) and WoW Forever**. Plays nicely with **Questie** and **Dialogue UI**.

## Sharing

- Press *Share* on several quests in your quest log: they go into a queue instead of failing.
- Or type **/qb** (or click the minimap button) to open the share window:
  - your quest log grouped by zone, folded zones included;
  - level (difficulty colour), tag (dungeon, elite...) and whether the quest is complete;
  - with Questie loaded, where each quest starts (NPC and zone);
  - tick quests one by one, a whole zone, all dungeon quests or everything, then **Share checked**, **Share zone** or **Share all**;
  - a status line shows which quest is going out, how many are left and who you are waiting for, with a **Cancel** button.
- Every button explains what it does when you hover it.

Your friends do **not** need the addon for the queue to work. With it, they get the extra receiving options below.

## Receiving

- When a quest is shared with you, a small panel asks **Accept all** or **Decline all**.
- Pick one and the panel goes away: the rest of the batch is answered in the background, with a chat line for each quest.
- Optional: accept quests shared by **friends**, your **guild** or the **group leader** without being asked.
- The panel stays visible even when Dialogue UI hides the rest of the interface.

## Options

Right-click the minimap button, press **Options** in the share window, or type **/qb options**:

- who gets their shared quests accepted automatically (friends, guild, group leader);
- how long *Accept all* / *Decline all* keeps answering (5, 10, 15 or 30 seconds);
- show or hide the minimap button (it also works with Minimap Button Button and similar collectors).
- choose **Automatic**, **English** or **Español**; automatic follows the game's language and changes apply immediately.

## Commands

- `/qb`: open the share window
- `/qb options`: options
- `/qb clear`: empty the share queue
- `/qb minimap`: show or hide the minimap button
- `/qb debug`: troubleshooting output if the queue does not move on

## Feedback

Bugs and ideas: https://github.com/Andressance/questbuffer/issues

---

*En español: comparte varias misiones con tu grupo de una vez, sin el error "está ocupado". Ventana `/qb` para elegir qué compartir, panel de Aceptar/Rechazar todas para quien recibe, aceptación automática configurable para amigos, hermandad o líder del grupo y selector de idioma automático, inglés o español.*
