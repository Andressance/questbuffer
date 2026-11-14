-- Run from the repo root: lua tests/test.lua
-- Mocks just enough of the WoW API to drive QuestBuffer.lua. The ERR_QUEST_PUSH_* strings below are
-- stand-ins: this checks the logic, not that the real client uses these exact texts.
local function stub() return setmetatable({}, { __index = function() return stub() end, __call = function() return stub() end }) end

local frames, timers, printed = {}, {}, {}
local function newFrame()
	local f = { handlers = {}, shown = true, checked = false }
	function f:SetScript(n, fn) self.handlers[n] = fn end
	function f:Show() self.shown = true if self.handlers.OnShow then self.handlers.OnShow(self) end end
	function f:Hide() self.shown = false end
	function f:IsShown() return self.shown end
	function f:SetShown(v) if v then self:Show() else self:Hide() end end
	function f:SetChecked(v) self.checked = v end
	function f:GetChecked() return self.checked end
	frames[#frames + 1] = f
	return setmetatable(f, { __index = function() return stub() end })
end

local selected, pushes, accepts, declines, isPlayer = 0, {}, 0, 0, true
local log = { { isHeader = true }, { questID = 11, title = "A" }, { questID = 12, title = "B" }, { questID = 13, title = "C" } }
GetLocale = function() return "enUS" end
IsInGroup = function() return true end
print = function(...) printed[#printed + 1] = table.concat({ ... }, " ") end
wipe = function(t) for k in pairs(t) do t[k] = nil end end
tinsert = table.insert
UISpecialFrames, UIParent, SlashCmdList = {}, {}, {}
CreateFrame = newFrame
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
}
QuestLogPushQuest = function() pushes[#pushes + 1] = selected end
ERR_QUEST_PUSH_SUCCESS_S = "Sharing quest with %s"
ERR_QUEST_PUSH_ACCEPTED_S = "%s has accepted your quest."
ERR_QUEST_PUSH_DECLINED_S = "%s has declined your quest."
UnitIsPlayer = function() return isPlayer end
UnitName = function() return "Bob" end
GetTitleText = function() return "Some quest" end
AcceptQuest = function() accepts = accepts + 1 end
DeclineQuest = function() declines = declines + 1 end

dofile("QuestBuffer.lua")

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
local function buttons() local t = {} for _, f in ipairs(frames) do if f.handlers.OnClick then t[#t + 1] = f end end return t end

-- sharer: 3 pushes in a row -> only the first goes out, the rest wait for answers
for _, id in ipairs({ 101, 102, 103 }) do selected = id QuestLogPushQuest() end
eq(#pushes, 1, "only first push sent immediately")
event("CHAT_MSG_SYSTEM", "Sharing quest with Bob")
run(1.5)
eq(#pushes, 1, "still waiting for Bob")
event("CHAT_MSG_SYSTEM", "Bob has accepted your quest.")
eq(#pushes, 2, "Bob answered -> second push")
eq(pushes[2], 102, "queue order")
run(1.5) -- nobody was prompted (e.g. already on quest): must not stall
eq(#pushes, 3, "no one prompted -> third push")
run(1.5)

-- batch window: lists only pushable quests, shares the checked ones through the queue
SlashCmdList.QUESTBUFFER("")
local rows = {}
for _, f in ipairs(frames) do if rawget(f, "questID") then rows[#rows + 1] = f end end
eq(#rows, 2, "header and unpushable quest hidden")
rows[1]:SetChecked(true)
rows[2]:SetChecked(true)
local btn = buttons()
btn[#btn].handlers.OnClick() -- "Share selected"
eq(pushes[4], 11, "batch share pushes first checked quest")
SlashCmdList.QUESTBUFFER("clear")

-- receiver: "Accept all" answers now and auto-answers the next shared quests, once each
event("QUEST_DETAIL")
btn[1].handlers.OnClick()
eq(accepts, 1, "accept all answers the pending quest")
event("QUEST_ACCEPTED")
event("QUEST_DETAIL")
event("QUEST_DETAIL") -- Dialogue UI may repeat the event
run(0.2)
eq(accepts, 2, "next quest auto-accepted exactly once")
btn[2].handlers.OnClick() -- "Decline all"
eq(declines, 1, "decline all answers the pending quest")
isPlayer = false
event("QUEST_FINISHED")
event("QUEST_DETAIL") -- NPC quest: untouched
run(0.2)
eq(accepts + declines, 3, "NPC quests are never auto-answered")

print = io.write and function(...) io.write(..., "\n") end
print("ok")
