-- QuestBuffer
-- Server rule: a player can only have ONE shared quest pending; a second push gets "X is busy".
-- Sharer side: pushes are queued and sent one at a time, as each recipient accepts/declines.
-- Receiver side: a small panel with "Accept all" / "Decline all" answers the rest of the batch.
-- Only listens to game events and calls AcceptQuest/DeclineQuest, so it works with Dialogue UI
-- (or the default quest frame) without touching either.
-- The batch share window lives in ShareWindow.lua and talks to this file through `ns`.

local _, ns = ...

local ANSWER_TIMEOUT = 60 -- sharer: give up waiting for slow/absent recipients (shortcut: fixed, no option)
local AUTO_TIMEOUT = 15 -- receiver: "all" mode ends this long after the last quest it answered

local L = { acceptAll = "Accept all", declineAll = "Decline all", from = "%s shares: %s",
	autoAccept = "Accepting all shared quests...", autoDecline = "Declining all shared quests...",
	queued = "QuestBuffer: %d shared quest(s) queued.", cleared = "QuestBuffer: queue cleared.",
	cantShare = "QuestBuffer: you must be in a group to share.",
	title = "Share quests", shareSelected = "Share selected (%d)", shareAll = "Share all",
	selectAll = "All", selectNone = "None", selectDungeon = "Dungeons", select = "Select", share = "Share",
	zone = "Zone", level = "Level", starts = "Starts", complete = "Complete",
	minimapTip = "Click: share quests. Drag: move." }
if GetLocale():sub(1, 2) == "es" then
	L = { acceptAll = "Aceptar todas", declineAll = "Borrar todas", from = "%s comparte: %s",
		autoAccept = "Aceptando todas las misiones compartidas...", autoDecline = "Borrando todas las misiones compartidas...",
		queued = "QuestBuffer: %d misión(es) compartida(s) en cola.", cleared = "QuestBuffer: cola vaciada.",
		cantShare = "QuestBuffer: tienes que estar en grupo para compartir.",
		title = "Compartir misiones", shareSelected = "Compartir selección (%d)", shareAll = "Compartir todas",
		selectAll = "Todas", selectNone = "Ninguna", selectDungeon = "Mazmorras", select = "Marcar", share = "Compartir",
		zone = "Zona", level = "Nivel", starts = "Empieza", complete = "Completada",
		minimapTip = "Clic: compartir misiones. Arrastrar: mover." }
end
ns.L = L

---------------------------------------------------------------- sharer: queue
local queue, waiting, expected, settled, timer, current = {}, false, {}, false, nil, nil

-- Turn a GlobalString like "%s has declined your quest." into a Lua pattern capturing the name.
local function pattern(key)
	local s = _G[key]
	if type(s) ~= "string" then return end
	s = s:gsub("[%(%)%.%+%-%*%?%[%]%^%$]", "%%%0"):gsub("%%%d%$s", "(.+)"):gsub("%%s", "(.+)")
	return "^" .. s .. "$"
end
local P = { start = pattern("ERR_QUEST_PUSH_SUCCESS_S"), accepted = pattern("ERR_QUEST_PUSH_ACCEPTED_S"),
	declined = pattern("ERR_QUEST_PUSH_DECLINED_S") }

-- Modern clients (Retail, WoW Forever) share by questID through QuestUtil.ShareQuest; Classic through
-- the selected quest + QuestLogPushQuest. We wrap both entry points; `pushing` lets our own send pass through.
local realPush = QuestLogPushQuest
local realShare = QuestUtil and QuestUtil.ShareQuest
local canShare = realShare or realPush
local pushing
local pump

-- Quest log selection: by questID on Retail/Forever, by log index on Classic.
local function selectedQuestID()
	if C_QuestLog and C_QuestLog.GetSelectedQuest then return C_QuestLog.GetSelectedQuest() end
	local index = GetQuestLogSelection and GetQuestLogSelection() or 0
	return index > 0 and select(8, GetQuestLogTitle(index)) or nil
end

local function selectQuest(questID)
	if C_QuestLog and C_QuestLog.SetSelectedQuest then return C_QuestLog.SetSelectedQuest(questID) end
	SelectQuestLogEntry(GetQuestLogIndexByID(questID))
end

local function send(questID)
	pushing = true
	local ok, err = pcall(function()
		if realShare then
			realShare(questID)
		else
			selectQuest(questID)
			realPush()
		end
	end)
	pushing = false
	if not ok then print(err) end
end

local function finish()
	if timer then timer:Cancel() end
	waiting, current = false, nil
	pump()
end

function pump()
	if waiting or not queue[1] then return end
	waiting, expected, settled = true, {}, false
	current = table.remove(queue, 1)
	send(current)
	timer = C_Timer.NewTimer(ANSWER_TIMEOUT, finish)
	-- failure replies (already on quest, too far...) arrive instantly; if nobody was actually prompted, move on
	C_Timer.After(1.5, function()
		settled = true
		if waiting and not next(expected) then finish() end
	end)
end

local function enqueue(questID, quiet)
	if questID == current then return end -- already out / already queued: not twice
	for _, id in ipairs(queue) do if id == questID then return end end
	queue[#queue + 1] = questID
	if not quiet then print(L.queued:format(#queue + (waiting and 1 or 0))) end
	pump()
end

-- Used by the share window: queue several quests, announce once.
function ns.share(ids)
	if not (canShare and IsInGroup()) then return print(L.cantShare) end
	for _, id in ipairs(ids) do enqueue(id, true) end
	print(L.queued:format(#queue + (waiting and 1 or 0)))
end

if realShare then
	QuestUtil.ShareQuest = function(questID, ...)
		if pushing or not IsInGroup() then return realShare(questID, ...) end
		enqueue(questID)
	end
end
if realPush then
	QuestLogPushQuest = function(...)
		local questID = selectedQuestID()
		if pushing or not IsInGroup() or not questID or questID == 0 then return realPush(...) end
		enqueue(questID)
	end
end

local debug
local function onSystemMessage(text)
	if issecretvalue and issecretvalue(text) then return end
	if debug and waiting then print("QuestBuffer system msg: " .. text) end
	if not waiting then return end
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
f:SetFrameStrata("FULLSCREEN_DIALOG") -- same strata as Dialogue UI's window; raised level keeps us on top of it
f:SetFrameLevel(200)
f:SetToplevel(true)
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", f.StopMovingOrSizing)
f:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 } })
f:Hide()
f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
f.text:SetPoint("TOP", 0, -14)
f.text:SetWidth(250)

local pending, scheduled, mode, modeTimer, title, giver

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
		-- the "giver" is a player only for shared quests
		pending = (UnitIsPlayer("questnpc") or UnitIsPlayer("npc")) and true or false
		if pending then
			title, giver = GetTitleText(), UnitName("questnpc") or UnitName("npc")
			if mode then
				setMode(mode) -- restart the "all" window
				-- Dialogue UI can fire QUEST_DETAIL repeatedly for one quest: answer once, after it has built its window
				if not scheduled then
					scheduled = true
					C_Timer.After(0.2, function() scheduled = false answer() end)
				end
			end
		end
	else
		pending = false
	end
	refresh()
end)

---------------------------------------------------------------- slash
SLASH_QUESTBUFFER1 = "/qb"
SlashCmdList.QUESTBUFFER = function(arg)
	if arg == "clear" then
		wipe(queue)
		print(L.cleared)
	elseif arg == "debug" then
		-- if the queue never advances on its own, the client's texts differ from these globals
		debug = not debug
		for _, key in ipairs({ "ERR_QUEST_PUSH_SUCCESS_S", "ERR_QUEST_PUSH_ACCEPTED_S", "ERR_QUEST_PUSH_DECLINED_S" }) do
			print(key .. " = " .. tostring(_G[key]))
		end
		print("QuestUtil.ShareQuest: " .. tostring(realShare ~= nil) .. ", QuestLogPushQuest: " .. tostring(realPush ~= nil))
	elseif arg == "minimap" then
		ns.toggleMinimap()
	else
		ns.toggleWindow()
	end
end
