-- Run from the repo root: lua tests/test.lua
-- Mocks just enough of the WoW API to drive QuestBuffer.lua and ShareWindow.lua. The ERR_QUEST_PUSH_*
-- strings below are stand-ins: this checks the logic, not that the real client uses these exact texts.
local function stub() return setmetatable({}, { __index = function() return stub() end, __call = function() return stub() end }) end

local frames, timers, printed = {}, {}, {}
local function newFrame(_, name)
	local f = { handlers = {}, shown = true, checked = false, enabled = true, name = name }
	function f:SetScript(n, fn) self.handlers[n] = fn end
	function f:Show() self.shown = true if self.handlers.OnShow then self.handlers.OnShow(self) end end
	function f:Hide() self.shown = false end
	function f:IsShown() return self.shown end
	function f:SetShown(v) if v then self:Show() else self:Hide() end end
	function f:SetChecked(v) self.checked = v end
	function f:GetChecked() return self.checked end
	function f:SetText(t) self.text = t end
	function f:SetEnabled(v) self.enabled = v end
	function f:CreateFontString()
		local fs = { text = "" }
		function fs:SetText(t) self.text = t end
		return setmetatable(fs, { __index = function(_, k) if type(k) == "string" and k:match("^%u") then return stub() end end })
	end
	frames[#frames + 1] = f
	return setmetatable(f, { __index = function(_, k) if type(k) == "string" and k:match("^%u") then return stub() end end })
end

local selected, pushes, accepts, declines, isPlayer, inGroup = 0, {}, 0, 0, true, true
local now = 0
GetTime = function() return now end
-- quest log: a zone, a dungeon group, a group whose only quest can't be shared
local log = {
	{ isHeader = true, title = "Elwynn Forest" },
	{ questID = 11, title = "Kobold Candles", level = 5 },
	{ questID = 12, title = "Wolves", level = 6 },
	{ isHeader = true, title = "The Deadmines" },
	{ questID = 21, title = "Red Silk Bandanas", level = 18 },
	{ isHeader = true, title = "Empty" },
	{ questID = 13, title = "Unshareable", level = 1 },
}
GetLocale = function() return "enUS" end
IsInGroup = function() return inGroup end
print = function(...) printed[#printed + 1] = table.concat({ ... }, " ") end
wipe = function(t) for k in pairs(t) do t[k] = nil end end
tinsert = table.insert
UISpecialFrames, UIParent, SlashCmdList, GameTooltip = {}, {}, {}, stub()
CreateFrame = newFrame
local cursorX, cursorY = 0, 0
Minimap = { GetCenter = function() return 100, 100 end, GetWidth = function() return 140 end, GetEffectiveScale = function() return 1 end }
GetCursorPosition = function() return cursorX, cursorY end
Enum = { QuestTag = { Dungeon = 1, Raid = 62 } }
GetQuestDifficultyColor = function() return { r = 1, g = 0.5, b = 0.25 } end
C_Map = { GetAreaInfo = function(id) return id == 12 and "Elwynn Forest" or nil end }
QuestieLoader = { _modules = { QuestieDB = {
	GetQuest = function(id) if id == 11 then return { Starts = { NPC = { 900 } } } end end,
	GetNPC = function(_, id) return { name = "Marshal McBride", spawns = { [12] = {} } } end,
	GetQuestTagInfo = function(id) if id == 21 then return 1, "Dungeon" end end,
} } }
C_Timer = {
	After = function(d, fn) timers[#timers + 1] = { d = d, fn = fn } end,
	NewTimer = function(d, fn) local t = { d = d, fn = fn } timers[#timers + 1] = t function t:Cancel() self.dead = true end return t end,
}
C_QuestLog = {
	GetSelectedQuest = function() return selected end,
	SetSelectedQuest = function(id) selected = id end,
	GetNumQuestLogEntries = function() return #log end,
	GetInfo = function(i) return log[i] end,
	IsPushableQuest = function(id) return id ~= 13 end,
	IsComplete = function(id) return id == 12 end,
}
QuestLogPushQuest = function() pushes[#pushes + 1] = selected end
-- like Blizzard's: selects the quest, then calls the global QuestLogPushQuest (our wrapper must not re-queue it)
QuestUtil = { ShareQuest = function(id) selected = id QuestLogPushQuest() end }
ERR_QUEST_PUSH_SUCCESS_S = "Sharing quest with %s"
ERR_QUEST_PUSH_ACCEPTED_S = "%s has accepted your quest."
ERR_QUEST_PUSH_DECLINED_S = "%s has declined your quest."
UnitIsPlayer = function() return isPlayer end
UnitName = function() return "Bob" end
GetTitleText = function() return "Some quest" end
AcceptQuest = function() accepts = accepts + 1 end
DeclineQuest = function() declines = declines + 1 end

local ns = {}
assert(loadfile("QuestBuffer.lua"))("QuestBuffer", ns)
assert(loadfile("ShareWindow.lua"))("QuestBuffer", ns)
assert(loadfile("MinimapButton.lua"))("QuestBuffer", ns)

local function run(delay) -- fire pending timers with this delay
	local todo = {}
	for i = #timers, 1, -1 do
		if timers[i].d == delay and not timers[i].dead then table.insert(todo, 1, table.remove(timers, i)) end
	end
	for _, t in ipairs(todo) do t.fn() end
end
local function eq(a, b, msg) assert(a == b, ("%s: expected %s, got %s"):format(msg, tostring(b), tostring(a))) end
local function event(e, ...)
	for _, f in ipairs(frames) do if f.handlers.OnEvent then f.handlers.OnEvent(f, e, ...) end end
end
local function button(text) -- first frame whose label is exactly `text` (or starts with it)
	for _, f in ipairs(frames) do
		if rawget(f, "text") and f.text:sub(1, #text) == text and f.handlers.OnClick then return f end
	end
	error("no button " .. text)
end
local function visibleRows()
	local t = {}
	for _, f in ipairs(frames) do if rawget(f, "check") and f.shown then t[#t + 1] = f end end
	return t
end
local function idle() run(1.5) end -- nobody prompted -> the queue moves on / goes idle

-- sharer: 3 pushes in a row -> only the first goes out, the rest wait for answers
for _, id in ipairs({ 101, 102, 103 }) do selected = id QuestLogPushQuest() end
eq(#pushes, 1, "only first push sent immediately")
event("CHAT_MSG_SYSTEM", "Sharing quest with Bob")
run(1.5)
eq(#pushes, 1, "still waiting for Bob")
event("CHAT_MSG_SYSTEM", "Bob has accepted your quest.")
eq(#pushes, 2, "Bob answered -> second push")
eq(pushes[2], 102, "queue order")
idle()
eq(#pushes, 3, "no one prompted -> third push")
idle()
QuestUtil.ShareQuest(201) -- the quest log's own Share entry point
eq(#pushes, 4, "QuestUtil.ShareQuest goes through the queue once")
eq(pushes[4], 201, "ShareQuest pushes that quest")
idle()

-- window: grouped by zone, empty/unshareable groups left out, info on each row
SlashCmdList.QUESTBUFFER("")
local rows = visibleRows()
eq(#rows, 5, "2 zone headers + 3 quests (the empty group is hidden)")
eq(rows[1].group.name, "Elwynn Forest", "first row is the zone")
eq(rows[2].quest.questID, 11, "quest under its zone")
assert(rows[2].title.text:find("Kobold Candles", 1, true) and rows[2].title.text:find("[5]", 1, true), "level + title")
eq(rows[2].sub.text, "Starts: Marshal McBride (Elwynn Forest)", "where it starts, from Questie")
assert(rows[3].title.text:find("Complete", 1, true), "completed quests are marked")
assert(rows[5].title.text:find("(Dungeon)", 1, true), "tag shown")
rows[2].handlers.OnEnter(rows[2]) -- tooltip builds without errors

-- selection: by dungeon, by zone checkbox, all / none
local IDLE = "Ready. Quests are sent to your group one at a time."
eq(ns.statusText(), IDLE, "status: idle")
button("Dungeons").handlers.OnClick()
local shareSel = button("Share checked")
eq(shareSel.text, "Share checked (1)", "dungeon quests checked")
eq(button("Share all").text, "Share all (3)", "share all shows how many")
button("None").handlers.OnClick()
eq(shareSel.text, "Share checked (0)", "cleared")
eq(shareSel.enabled, false, "nothing checked -> disabled")
shareSel.handlers.OnEnter(shareSel) -- tooltip explains why it is disabled, without errors
rows[1].check.handlers.OnClick(rows[1].check) -- zone checkbox
eq(shareSel.text, "Share checked (2)", "zone checkbox checks the whole zone")
eq(rows[1].check.checked, true, "zone checkbox shows checked when all its quests are")
rows[1].check.handlers.OnClick(rows[1].check)
eq(shareSel.text, "Share checked (0)", "and unchecks it")
rows[1].check.handlers.OnEnter(rows[1].check)
rows[1].shr.handlers.OnEnter(rows[1].shr)

-- sharing: checked, one zone, everything; the status line follows the queue
button("Dungeons").handlers.OnClick()
shareSel.handlers.OnClick()
eq(pushes[#pushes], 21, "share checked pushes the dungeon quest")
eq(shareSel.text, "Share checked (0)", "checks cleared after sharing")
local line1, line2 = ns.statusText()
assert(line1:find("Red Silk Bandanas", 1, true), "status names the quest being shared")
eq(line2, nil, "nobody to wait for yet")
eq(button("Cancel").shown, true, "cancel visible while sharing")
event("CHAT_MSG_SYSTEM", "Sharing quest with Bob")
line1, line2 = ns.statusText()
eq(line2, "Waiting for: Bob", "status says who has to answer")
run(1.5)
event("CHAT_MSG_SYSTEM", "Bob has accepted your quest.")
eq(ns.statusText(), IDLE, "back to idle once Bob answers")
eq(button("Cancel").shown, false, "cancel hidden when idle")
rows[1].shr.handlers.OnClick() -- zone "Share zone"
eq(pushes[#pushes], 11, "zone share starts with its first quest")
eq(printed[#printed], "QuestBuffer: 2 shared quest(s) queued.", "announced once for the zone")
idle() -- 11 done -> 12 goes out
eq(pushes[#pushes], 12, "second quest of the zone follows")
idle()
button("Share all").handlers.OnClick()
eq(printed[#printed], "QuestBuffer: 3 shared quest(s) queued.", "everything queued")
button("Share all").handlers.OnClick()
eq(printed[#printed], "QuestBuffer: 3 shared quest(s) queued.", "already-queued quests are not queued twice")
local before = #pushes
button("Cancel").handlers.OnClick()
idle()
eq(#pushes, before, "cancel: nothing else goes out")
eq(ns.statusText(), IDLE, "idle after cancelling")

-- out of a group: buttons disabled and the status says why
inGroup = false
event("GROUP_ROSTER_UPDATE")
eq(button("Share all").enabled, false, "no group -> share all disabled")
eq(ns.statusText(), "You are not in a group: join one to share quests.", "status explains it")
button("Share all").handlers.OnClick()
eq(printed[#printed], "QuestBuffer: you must be in a group to share.", "needs a group")
inGroup = true
event("GROUP_ROSTER_UPDATE")
eq(button("Share all").enabled, true, "back in a group")

-- collapsing a zone hides its quests
rows[1].handlers.OnClick()
eq(#visibleRows(), 3, "Elwynn collapsed: 2 headers + the dungeon quest")
rows[1].handlers.OnClick()
eq(#visibleRows(), 5, "expanded again")

-- the log changes while the window is open: refresh once (debounced)
log[#log + 1] = { questID = 31, title = "New", level = 9 }
log[6], log[7], log[8] = log[7], log[6], log[8] -- keep "Empty" header with its quest; new quest goes under it
event("QUEST_LOG_UPDATE") -- right after our own build: an echo, ignored
run(0.3)
eq(#visibleRows(), 5, "echo of our own build does not rebuild")
now = now + 2
event("QUEST_LOG_UPDATE")
event("QUEST_LOG_UPDATE")
run(0.3)
eq(#visibleRows(), 7, "new quest and its group appear")

-- receiver: "Accept all" answers now and auto-answers the next shared quests, once each
event("QUEST_DETAIL")
button("Accept all").handlers.OnClick()
eq(accepts, 1, "accept all answers the pending quest")
event("QUEST_ACCEPTED")
event("QUEST_DETAIL")
event("QUEST_DETAIL") -- Dialogue UI may repeat the event
run(0.2)
eq(accepts, 2, "next quest auto-accepted exactly once")
button("Decline all").handlers.OnClick()
eq(declines, 1, "decline all answers the pending quest")
isPlayer = false
event("QUEST_FINISHED")
event("QUEST_DETAIL") -- NPC quest: untouched
run(0.2)
eq(accepts + declines, 3, "NPC quests are never auto-answered")

-- minimap button: set up on ADDON_LOADED, click opens the window, drag stores the angle, /qb minimap hides it
event("ADDON_LOADED", "SomethingElse")
eq(QuestBufferDB, nil, "minimap: ignores other addons")
event("ADDON_LOADED", "QuestBuffer")
eq(QuestBufferDB.angle, 215, "minimap: default angle")
local function named(n) for _, f in ipairs(frames) do if f.name == n then return f end end error(n) end
local mb, shareWin = named("QuestBufferMinimapButton"), named("QuestBufferShareFrame")
eq(mb.shown, true, "minimap: visible by default")
mb.handlers.OnEnter(mb) -- tooltip with the queue status builds without errors
local wasShown = shareWin.shown
mb.handlers.OnClick()
eq(shareWin.shown, not wasShown, "minimap: click toggles the share window")
cursorX, cursorY = 300, 100 -- straight right of the minimap centre
mb.handlers.OnDragStart(mb)
mb.handlers.OnUpdate()
eq(QuestBufferDB.angle, 0, "minimap: drag stores the angle")
mb.handlers.OnDragStop(mb)
eq(mb.handlers.OnUpdate, nil, "minimap: drag stops following the cursor")
SlashCmdList.QUESTBUFFER("minimap")
eq(mb.shown, false, "minimap: /qb minimap hides it")
eq(QuestBufferDB.hide, true, "minimap: and remembers it")
SlashCmdList.QUESTBUFFER("minimap")
eq(mb.shown, true, "minimap: and shows it again")

-- ===== Classic: no C_QuestLog log functions and no QuestUtil, legacy globals instead
frames, timers, pushes, printed = {}, {}, {}, {}
local legacy = {
	{ title = "Elwynn Forest", isHeader = true },
	{ title = "Kobold Candles", level = 5, questID = 11 },
	{ title = "Wolves", level = 6, questID = 12, complete = 1 },
	{ title = "The Deadmines", isHeader = true },
	{ title = "Red Silk Bandanas", level = 18, questID = 21, tag = "Dungeon" },
	{ title = "Empty", isHeader = true },
	{ title = "Unshareable", level = 1, questID = 13 },
}
local sel = 0
C_QuestLog, QuestUtil, QuestieLoader, C_Map, GetQuestTagInfo = nil, nil, nil, nil, nil
LFG_TYPE_DUNGEON, LFG_TYPE_RAID = "Dungeon", "Raid"
GetNumQuestLogEntries = function() return #legacy, 3 end
GetQuestLogTitle = function(i)
	local e = legacy[i]
	if e then return e.title, e.level, e.tag, e.isHeader, false, e.complete, nil, e.questID end
end
SelectQuestLogEntry = function(i) sel = i end
GetQuestLogSelection = function() return sel end
GetQuestLogIndexByID = function(id) for i, e in ipairs(legacy) do if e.questID == id then return i end end return 0 end
GetQuestLogPushable = function() return legacy[sel] and legacy[sel].questID ~= 13 end
QuestLogPushQuest = function() pushes[#pushes + 1] = legacy[sel].questID end
ns = {}
for _, file in ipairs({ "QuestBuffer.lua", "ShareWindow.lua" }) do assert(loadfile(file))("QuestBuffer", ns) end

sel = 3 -- the player has a quest selected in the log
SlashCmdList.QUESTBUFFER("")
local lrows = visibleRows()
eq(#lrows, 5, "classic: same grouping, unshareable quest left out")
eq(sel, 3, "classic: checking pushability puts the selection back")
assert(lrows[3].title.text:find("Complete", 1, true), "classic: completion from the log")
assert(lrows[5].title.text:find("(Dungeon)", 1, true), "classic: tag from the log")
button("Dungeons").handlers.OnClick()
eq(button("Share checked").text, "Share checked (1)", "classic: dungeon quests found by tag name")
button("Share checked").handlers.OnClick()
eq(pushes[1], 21, "classic: shares by selecting the log entry")
idle()
sel = 2 -- the player selects a quest in the log and presses its own Share button
QuestLogPushQuest()
eq(pushes[2], 11, "classic: the log's own Share button goes through the queue")

io.write("ok\n")
