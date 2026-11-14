-- QuestBuffer
-- Server rule: a player can only have ONE shared quest pending; a second push gets "X is busy".
-- Sharer side: pushes are queued and sent one at a time, as each recipient accepts/declines.
-- Receiver side: a small panel with "Accept all" / "Decline all" answers the rest of the batch.
-- Only listens to game events and calls AcceptQuest/DeclineQuest, so it works with Dialogue UI
-- (or the default quest frame) without touching either.

local ANSWER_TIMEOUT = 60 -- sharer: give up waiting for slow/absent recipients (shortcut: fixed, no option)
local AUTO_TIMEOUT = 15 -- receiver: "all" mode ends this long after the last quest it answered

local L = { acceptAll = "Accept all", declineAll = "Decline all", from = "%s shares: %s",
	autoAccept = "Accepting all shared quests...", autoDecline = "Declining all shared quests...",
	queued = "QuestBuffer: %d shared quest(s) queued.", cleared = "QuestBuffer: queue cleared." }
if GetLocale():sub(1, 2) == "es" then
	L = { acceptAll = "Aceptar todas", declineAll = "Borrar todas", from = "%s comparte: %s",
		autoAccept = "Aceptando todas las misiones compartidas...", autoDecline = "Borrando todas las misiones compartidas...",
		queued = "QuestBuffer: %d mision(es) compartida(s) en cola.", cleared = "QuestBuffer: cola vaciada." }
end

---------------------------------------------------------------- sharer: queue
local queue, waiting, expected, settled, timer = {}, false, {}, false, nil

-- Turn a GlobalString like "%s has declined your quest." into a Lua pattern capturing the name.
local function pattern(key)
	local s = _G[key]
	if type(s) ~= "string" then return end
	s = s:gsub("[%(%)%.%+%-%*%?%[%]%^%$]", "%%%0"):gsub("%%%d%$s", "(.+)"):gsub("%%s", "(.+)")
	return "^" .. s .. "$"
end
local P = { start = pattern("ERR_QUEST_PUSH_SUCCESS_S"), accepted = pattern("ERR_QUEST_PUSH_ACCEPTED_S"),
	declined = pattern("ERR_QUEST_PUSH_DECLINED_S") }

local realPush = QuestLogPushQuest
local pump

local function finish()
	if timer then timer:Cancel() end
	waiting = false
	pump()
end

function pump()
	if waiting or not queue[1] then return end
	waiting, expected, settled = true, {}, false
	C_QuestLog.SetSelectedQuest(table.remove(queue, 1))
	realPush()
	timer = C_Timer.NewTimer(ANSWER_TIMEOUT, finish)
	-- failure replies (already on quest, too far...) arrive instantly; if nobody was actually prompted, move on
	C_Timer.After(1.5, function()
		settled = true
		if waiting and not next(expected) then finish() end
	end)
end

if realPush then
	QuestLogPushQuest = function(...)
		local questID = C_QuestLog.GetSelectedQuest()
		if not IsInGroup() or not questID or questID == 0 then return realPush(...) end
		queue[#queue + 1] = questID
		print(L.queued:format(#queue + (waiting and 1 or 0)))
		pump()
	end
end

local function onSystemMessage(text)
	if not waiting or (issecretvalue and issecretvalue(text)) then return end
	local name = P.start and text:match(P.start)
	if name then expected[name] = true return end
	name = (P.accepted and text:match(P.accepted)) or (P.declined and text:match(P.declined))
	if name then
		expected[name] = nil
		if settled and not next(expected) then finish() end
	end
end

---------------------------------------------------------------- receiver: panel
local f = CreateFrame("Frame", "QuestBufferFrame", UIParent, "BackdropTemplate")
f:SetSize(290, 80)
f:SetPoint("TOP", 0, -140)
f:SetFrameStrata("FULLSCREEN_DIALOG")
f:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 } })
f:Hide()
f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
f.text:SetPoint("TOP", 0, -14)
f.text:SetWidth(250)

local pending, mode, modeTimer, title, giver

local function refresh()
	if not (pending or mode) then return f:Hide() end
	f.text:SetText(mode == "accept" and L.autoAccept or mode == "decline" and L.autoDecline or L.from:format(giver or "?", title or "?"))
	f:Show()
end

local function answer()
	if not pending then return end
	if mode == "accept" then AcceptQuest() else DeclineQuest() end
end

local function setMode(m)
	mode = m
	if modeTimer then modeTimer:Cancel() end
	if m then modeTimer = C_Timer.NewTimer(AUTO_TIMEOUT, function() mode = nil refresh() end) end
end

local function button(label, anchor, m)
	local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	b:SetSize(125, 24)
	b:SetPoint("BOTTOM" .. anchor, anchor == "LEFT" and 14 or -14, 12)
	b:SetText(label)
	b:SetScript("OnClick", function() setMode(m) answer() refresh() end)
end
button(L.acceptAll, "LEFT", "accept")
button(L.declineAll, "RIGHT", "decline")

local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", 2, 2)
close:SetScript("OnClick", function() setMode(nil) refresh() end)

---------------------------------------------------------------- events
local events = CreateFrame("Frame")
for _, e in ipairs({ "QUEST_DETAIL", "QUEST_ACCEPTED", "QUEST_FINISHED", "CHAT_MSG_SYSTEM" }) do events:RegisterEvent(e) end
events:SetScript("OnEvent", function(_, event, arg1)
	if event == "CHAT_MSG_SYSTEM" then return onSystemMessage(arg1) end
	if event == "QUEST_DETAIL" then
		pending = UnitIsPlayer("questnpc") -- the "giver" is a player only for shared quests
		if pending then
			title, giver = GetTitleText(), UnitName("questnpc")
			if mode then setMode(mode) C_Timer.After(0.2, answer) end -- restart the "all" window
		end
	else
		pending = false
	end
	refresh()
end)

SLASH_QUESTBUFFER1 = "/qb"
SlashCmdList.QUESTBUFFER = function()
	wipe(queue)
	print(L.cleared)
end
