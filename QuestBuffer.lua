-- QuestBuffer
-- Server rule: a player can only have ONE shared quest pending; a second push gets "X is busy".
-- Sharer side: pushes are queued and sent one at a time, as each recipient accepts/declines.
-- Receiver side: a small panel with "Accept all" / "Decline all" answers the rest of the batch.
-- Only listens to game events and calls AcceptQuest/DeclineQuest, so it works with Dialogue UI
-- (or the default quest frame) without touching either.
-- The batch share window lives in ShareWindow.lua and talks to this file through `ns`.

local _, ns = ...

local ANSWER_TIMEOUT = 60 -- sharer: give up waiting for slow/absent recipients (shortcut: fixed, no option)

local EN = {
	-- receiver panel
	from = "%s shares a quest with you:", acceptAll = "Accept all", declineAll = "Decline all",
	acceptAllTip = "Accepts this quest and every quest shared with you in the next %d seconds.",
	declineAllTip = "Declines this quest and every quest shared with you in the next %d seconds.",
	autoAccepted = "QuestBuffer: accepted %s (shared by %s) automatically.",
	autoDeclined = "QuestBuffer: declined %s (shared by %s) automatically.",
	closeTitle = "Close", closeTip = "Hide this panel and answer by hand.",
	-- chat
	queued = "QuestBuffer: %d shared quest(s) queued.", cleared = "QuestBuffer: queue cleared.",
	cantShare = "QuestBuffer: you must be in a group to share.",
	-- share window
	title = "Share quests", selectLabel = "Check:", selectAll = "All", selectNone = "None", selectDungeon = "Dungeons",
	selectAllTip = "Check every quest in the list.", selectNoneTip = "Uncheck everything.",
	selectDungeonTip = "Check only dungeon and raid quests.",
	shareChecked = "Share checked (%d)", shareAll = "Share all (%d)",
	shareCheckedTip = "Sends the checked quests to your group one at a time: the next one goes out when everyone has accepted or declined the previous one.",
	shareAllTip = "Sends every quest in the list to your group, one at a time.",
	noneChecked = "Tick the box next to a quest to check it.",
	zoneCheckTip = "Check or uncheck every quest in %s.", collapseTip = "Click to collapse or expand this zone.",
	shareZone = "Share zone", shareZoneTip = "Sends the %d quest(s) of %s to your group, one at a time.",
	emptyList = "No quests can be shared.\nQuests under a collapsed zone in your quest log are not listed: expand it.",
	statusNoGroup = "You are not in a group: join one to share quests.",
	statusIdle = "Ready. Quests are sent to your group one at a time.",
	statusSharing = "Sharing |cffffffff%s|r (%d more in queue)", statusWaiting = "Waiting for: %s",
	cancelQueue = "Cancel", cancelQueueTip = "Empties the queue. The quest already sent stays pending for whoever has not answered yet.",
	zone = "Zone", level = "Level", starts = "Starts", complete = "Complete",
	-- minimap button
	minimapClick = "Click: open the share window", minimapDrag = "Drag: move this button", minimapHide = "/qb minimap: hide this button",
	minimapRight = "Right-click: options",
	-- options
	options = "Options", optionsTip = "Automatic accepting, how long \"Accept all\" lasts, and the minimap button.",
	optionsTitle = "QuestBuffer options", optAutoHeading = "Accept automatically the quests shared by:",
	optFriends = "Friends", optFriendsTip = "Characters on your friend list and Battle.net friends.",
	optGuild = "Guild members", optGuildTip = "Players in your guild.",
	optLeader = "The group leader", optLeaderTip = "Whoever leads your party or raid.",
	optTimeoutHeading = "\"Accept all\" / \"Decline all\" keeps answering for:",
	optTimeoutTip = "How long after the last shared quest it keeps answering by itself.",
	optOtherHeading = "Other", optMinimap = "Show the minimap button", optMinimapTip = "Same as /qb minimap.",
	optLanguageHeading = "Language", optLanguageAuto = "Automatic", optLanguageEnglish = "English", optLanguageSpanish = "Español",
}
local ES = {
		from = "%s te comparte una misión:", acceptAll = "Aceptar todas", declineAll = "Rechazar todas",
		acceptAllTip = "Acepta esta misión y todas las que te compartan en los próximos %d segundos.",
		declineAllTip = "Rechaza esta misión y todas las que te compartan en los próximos %d segundos.",
		autoAccepted = "QuestBuffer: aceptada automáticamente %s (de %s).",
		autoDeclined = "QuestBuffer: rechazada automáticamente %s (de %s).",
		closeTitle = "Cerrar", closeTip = "Oculta este panel y responde a mano.",
		queued = "QuestBuffer: %d misión(es) compartida(s) en cola.", cleared = "QuestBuffer: cola vaciada.",
		cantShare = "QuestBuffer: tienes que estar en grupo para compartir.",
		title = "Compartir misiones", selectLabel = "Marcar:", selectAll = "Todas", selectNone = "Ninguna", selectDungeon = "Mazmorras",
		selectAllTip = "Marca todas las misiones de la lista.", selectNoneTip = "Desmarca todo.",
		selectDungeonTip = "Marca solo las misiones de mazmorra y banda.",
		shareChecked = "Compartir marcadas (%d)", shareAll = "Compartir todas (%d)",
		shareCheckedTip = "Envía las misiones marcadas a tu grupo de una en una: la siguiente sale cuando todos han aceptado o rechazado la anterior.",
		shareAllTip = "Envía todas las misiones de la lista a tu grupo, de una en una.",
		noneChecked = "Marca la casilla de una misión para elegirla.",
		zoneCheckTip = "Marca o desmarca todas las misiones de %s.", collapseTip = "Clic para plegar o desplegar esta zona.",
		shareZone = "Compartir zona", shareZoneTip = "Envía las %d misión(es) de %s a tu grupo, de una en una.",
		emptyList = "No hay misiones que se puedan compartir.\nLas misiones de una zona plegada en tu diario no salen: despliégala.",
		statusNoGroup = "No estás en grupo: únete a uno para compartir misiones.",
		statusIdle = "Listo. Las misiones se envían a tu grupo de una en una.",
		statusSharing = "Compartiendo |cffffffff%s|r (%d más en cola)", statusWaiting = "Esperando a: %s",
		cancelQueue = "Cancelar", cancelQueueTip = "Vacía la cola. La misión ya enviada sigue pendiente para quien no haya respondido.",
		zone = "Zona", level = "Nivel", starts = "Empieza", complete = "Completada",
		minimapClick = "Clic: abrir la ventana de compartir", minimapDrag = "Arrastrar: mover este botón", minimapHide = "/qb minimap: ocultar este botón",
		minimapRight = "Clic derecho: opciones",
		options = "Opciones", optionsTip = "Aceptación automática, cuánto dura \"Aceptar todas\" y el botón del minimapa.",
		optionsTitle = "Opciones de QuestBuffer", optAutoHeading = "Aceptar automáticamente las misiones que comparten:",
		optFriends = "Amigos", optFriendsTip = "Personajes de tu lista de amigos y amigos de Battle.net.",
		optGuild = "Miembros de la hermandad", optGuildTip = "Jugadores de tu hermandad.",
		optLeader = "El líder del grupo", optLeaderTip = "Quien lidera tu grupo o banda.",
		optTimeoutHeading = "\"Aceptar todas\" / \"Rechazar todas\" sigue respondiendo durante:",
		optTimeoutTip = "Cuánto tiempo después de la última misión compartida sigue respondiendo solo.",
		optOtherHeading = "Otros", optMinimap = "Mostrar el botón del minimapa", optMinimapTip = "Lo mismo que /qb minimap.",
		optLanguageHeading = "Idioma", optLanguageAuto = "Automático", optLanguageEnglish = "English", optLanguageSpanish = "Español",
}

local L = {}
ns.L = L
function ns.setLanguage(choice)
	local lang = (choice == "es" or choice == "en") and choice or nil
	if not lang then lang = GetLocale():sub(1, 2) == "es" and "es" or "en" end
	local source = lang == "es" and ES or EN
	wipe(L)
	for k, v in pairs(source) do L[k] = v end
	if ns.refreshLanguage then ns.refreshLanguage() end
end
ns.setLanguage("auto")

-- Saved settings. Only call this once ADDON_LOADED has fired: before that the saved table is not loaded yet.
local DEFAULTS = {
	autoTimeout = 15, -- receiver: "all" mode ends this long after the last quest it answered
	autoFriends = false, autoGuild = false, autoLeader = false, -- accept shares from these players without asking
	language = "auto",
}
function ns.db()
	QuestBufferDB = QuestBufferDB or {}
	for k, v in pairs(DEFAULTS) do if QuestBufferDB[k] == nil then QuestBufferDB[k] = v end end
	return QuestBufferDB
end

-- Tooltip with a gold title and a wrapped explanation; either may be a function, evaluated on hover.
function ns.tip(frame, title, text)
	if frame.SetMotionScriptsWhileDisabled then frame:SetMotionScriptsWhileDisabled(true) end -- explain disabled buttons too
	frame:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(type(title) == "function" and title(self) or title, 1, 0.82, 0)
		local t = type(text) == "function" and text(self) or text
		if t then GameTooltip:AddLine(t, 1, 1, 1, true) end
		GameTooltip:Show()
	end)
	frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

---------------------------------------------------------------- sharer: queue
local queue, waiting, expected, settled, timer, current = {}, false, {}, false, nil, nil

local function notify() if ns.onQueueChange then ns.onQueueChange() end end

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
	local index = GetQuestLogIndexByID(questID)
	-- shortcut: a quest under a folded zone has no index on Classic, so open all zones (they stay open)
	if index == 0 and ExpandQuestHeader then
		ExpandQuestHeader(0)
		index = GetQuestLogIndexByID(questID)
	end
	SelectQuestLogEntry(index)
end

local function send(questID)
	if InCombatLockdown() then
		print("QuestBuffer: no se puede compartir en combate.")
		return false
	end
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
	if not ok then
		print(err)
		return false
	end
	return true
end

local function finish()
	if timer then timer:Cancel() end
	waiting, current = false, nil
	pump()
	notify()
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
	notify()
end

function ns.canShare() return canShare and IsInGroup() and true or false end

-- Used by the share window: queue several quests, announce once.
function ns.share(ids)
	if not ns.canShare() then return print(L.cantShare) end
	for _, id in ipairs(ids) do enqueue(id, true) end
	print(L.queued:format(#queue + (waiting and 1 or 0)))
end

-- The quest out right now (nil when idle), how many wait behind it, and who still has to answer it.
function ns.status()
	local names = {}
	for name in pairs(expected) do names[#names + 1] = name end
	table.sort(names)
	return current, #queue, names
end

function ns.clearQueue()
	wipe(queue)
	print(L.cleared)
	notify()
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
	if name then
		expected[name] = true
		return notify()
	end
	name = (P.accepted and text:match(P.accepted)) or (P.declined and text:match(P.declined))
	if name then
		expected[name] = nil
		if settled and not next(expected) then return finish() end
		notify()
	end
end

---------------------------------------------------------------- receiver: panel
-- No parent on purpose: during a dialogue Dialogue UI hides or fades UIParent (its "hide UI" option), and this
-- panel has to stay visible right then. Dialogue UI's own window is parentless for the same reason.
-- Without UIParent we copy its scale by hand (and again when the UI scale changes).
local f = CreateFrame("Frame", "QuestBufferFrame", nil, "BackdropTemplate")
local function matchScale() f:SetScale(UIParent:GetScale()) end
matchScale()
f:SetSize(300, 100)
f:SetPoint("TOP", WorldFrame, "TOP", 0, -140)
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
f.line1 = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
f.line1:SetPoint("TOP", 0, -14)
f.line1:SetWidth(260)
f.line2 = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
f.line2:SetPoint("TOP", f.line1, "BOTTOM", 0, -4)
f.line2:SetWidth(260)

local pending, scheduled, mode, modeTimer, title, giver

-- The panel only asks about a quest waiting for an answer. It stays out of the way while a quest is being
-- answered automatically ("all" mode, or a trusted player), and each automatic answer gets a chat line.
local function refresh()
	if not pending or mode or scheduled then return f:Hide() end
	f.line1:SetText(L.from:format(giver or "?"))
	f.line2:SetText(title or "?")
	f:Show()
end

local function answer(how, auto)
	if not pending then return end
	if how == "accept" then AcceptQuest() else DeclineQuest() end
	if auto then print((how == "accept" and L.autoAccepted or L.autoDeclined):format(title or "?", giver or "?")) end
end

-- Dialogue UI can fire QUEST_DETAIL repeatedly for one quest: answer once, after it has built its window.
local function answerSoon(how)
	if scheduled then return end
	scheduled = true
	C_Timer.After(0.2, function() scheduled = false answer(how, true) end)
end

local function setMode(m)
	mode = m
	if modeTimer then modeTimer:Cancel() end
	if m then modeTimer = C_Timer.NewTimer(ns.db().autoTimeout, function() mode = nil refresh() end) end
end

-- Friend, guild member or group leader, as ticked in the options.
local function trustedGiver()
	local db = ns.db()
	local unit = UnitExists("questnpc") and "questnpc" or "npc"
	local guid = UnitGUID(unit)
	if db.autoFriends and guid and ((C_FriendList and C_FriendList.IsFriend and C_FriendList.IsFriend(guid))
		or (C_BattleNet and C_BattleNet.GetAccountInfoByGUID and C_BattleNet.GetAccountInfoByGUID(guid))) then
		return true
	end
	if db.autoGuild and UnitIsInMyGuild(unit) then return true end
	if db.autoLeader and UnitIsGroupLeader(unit) then return true end
	return false
end

local function button(label, anchor, m, tipText)
	local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	b:SetSize(130, 24)
	b:SetPoint("BOTTOM" .. anchor, anchor == "LEFT" and 14 or -14, 12)
	b:SetText(label)
	b:SetScript("OnClick", function() setMode(m) answer(m) refresh() end)
	ns.tip(b, label, function() return tipText:format(ns.db().autoTimeout) end)
	return b
end
local acceptButton = button(L.acceptAll, "LEFT", "accept", L.acceptAllTip)
local declineButton = button(L.declineAll, "RIGHT", "decline", L.declineAllTip)

local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", 2, 2)
close:SetScript("OnClick", function() setMode(nil) f:Hide() end)
ns.tip(close, L.closeTitle, L.closeTip)

local previousRefreshLanguage = ns.refreshLanguage
ns.refreshLanguage = function()
	if previousRefreshLanguage then previousRefreshLanguage() end
	acceptButton:SetText(L.acceptAll)
	declineButton:SetText(L.declineAll)
	ns.tip(acceptButton, L.acceptAll, L.acceptAllTip)
	ns.tip(declineButton, L.declineAll, L.declineAllTip)
	ns.tip(close, L.closeTitle, L.closeTip)
	refresh()
end

---------------------------------------------------------------- events
local events = CreateFrame("Frame")
for _, e in ipairs({ "QUEST_DETAIL", "QUEST_ACCEPTED", "QUEST_FINISHED", "CHAT_MSG_SYSTEM", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }) do
	events:RegisterEvent(e)
end
events:SetScript("OnEvent", function(_, event, arg1)
	if event == "CHAT_MSG_SYSTEM" then return onSystemMessage(arg1) end
	if event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then return matchScale() end
	if event == "QUEST_DETAIL" then
		-- the "giver" is a player only for shared quests
		pending = (UnitIsPlayer("questnpc") or UnitIsPlayer("npc")) and true or false
		if pending then
			title, giver = GetTitleText(), UnitName("questnpc") or UnitName("npc")
			if mode then
				setMode(mode) -- restart the "all" window
				answerSoon(mode)
			elseif trustedGiver() then
				answerSoon("accept")
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
		ns.clearQueue()
	elseif arg == "debug" then
		-- if the queue never advances on its own, the client's texts differ from these globals
		debug = not debug
		for _, key in ipairs({ "ERR_QUEST_PUSH_SUCCESS_S", "ERR_QUEST_PUSH_ACCEPTED_S", "ERR_QUEST_PUSH_DECLINED_S" }) do
			print(key .. " = " .. tostring(_G[key]))
		end
		print("QuestUtil.ShareQuest: " .. tostring(realShare ~= nil) .. ", QuestLogPushQuest: " .. tostring(realPush ~= nil))
	elseif arg == "minimap" then
		ns.toggleMinimap()
	elseif arg == "options" or arg == "opciones" then
		ns.toggleOptions()
	else
		ns.toggleWindow()
	end
end
