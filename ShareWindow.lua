-- Batch share window: the quest log grouped by zone/category, with level, tag and, when Questie is
-- loaded, where each quest starts. Select by hand, by zone, dungeon quests or all, then share through the queue.
local _, ns = ...
local L = ns.L

local WIDTH, ROW_H, ROW_Q = 330, 22, 38 -- quest rows are taller when they carry a second "starts at" line
local groups, allQuests, checked, collapsed, rows = {}, {}, {}, {}, {}
local layout, updateCount, shareSel

local DUNGEON = {}
for _, key in ipairs({ "Dungeon", "Raid", "Raid10", "Raid25" }) do
	local id = Enum and Enum.QuestTag and Enum.QuestTag[key]
	if id then DUNGEON[id] = true end
end

---------------------------------------------------------------- quest info
-- Questie's corrected tag if it is there, else the game's.
local function questieDB()
	local loader = rawget(_G, "QuestieLoader")
	return loader and loader._modules and loader._modules.QuestieDB
end

local function tagOf(questID)
	local db = questieDB()
	if db then
		local ok, id, name = pcall(db.GetQuestTagInfo, questID)
		if ok and id then return id, name end
	end
	local info = C_QuestLog and C_QuestLog.GetQuestTagInfo and C_QuestLog.GetQuestTagInfo(questID)
	if info then return info.tagID, info.tagName end
	if GetQuestTagInfo then return GetQuestTagInfo(questID) end -- Classic
end

-- "Marshal McBride (Elwynn Forest)" from Questie's database; nil without Questie or when it doesn't know the quest.
local function startsAt(questID)
	local db = questieDB()
	if not db then return end
	local ok, text = pcall(function()
		local quest = db.GetQuest(questID)
		local npcID = quest and quest.Starts and quest.Starts.NPC and quest.Starts.NPC[1]
		local npc = npcID and db:GetNPC(npcID)
		if not npc or not npc.name then return end
		local zoneID = npc.spawns and next(npc.spawns)
		local zone = zoneID and C_Map and C_Map.GetAreaInfo and C_Map.GetAreaInfo(zoneID)
		return zone and (npc.name .. " (" .. zone .. ")") or npc.name
	end)
	return ok and text or nil
end

local function levelColor(level)
	local c = level and level > 0 and GetQuestDifficultyColor and GetQuestDifficultyColor(level)
	if not c then return "|cffffffff" end
	return ("|cff%02x%02x%02x"):format(math.floor(c.r * 255 + 0.5), math.floor(c.g * 255 + 0.5), math.floor(c.b * 255 + 0.5))
end

local function titleText(q)
	local s = ("%s[%d]|r %s"):format(levelColor(q.level), q.level or 0, q.title)
	if q.tag then s = s .. " |cff9d9d9d(" .. q.tag .. ")|r" end
	if q.complete then s = s .. " |cff20ff20(" .. L.complete .. ")|r" end
	return s
end

-- The quest log, however the client exposes it: C_QuestLog on Retail/Forever, the legacy globals on Classic.
-- Entries under a collapsed zone are not listed by either API.
local function logEntries()
	local t = {}
	if C_QuestLog and C_QuestLog.GetInfo and C_QuestLog.GetNumQuestLogEntries then
		for i = 1, C_QuestLog.GetNumQuestLogEntries() do
			local info = C_QuestLog.GetInfo(i)
			if info then
				t[#t + 1] = { index = i, isHeader = info.isHeader, title = info.title, level = info.level,
					questID = info.questID, hidden = info.isHidden,
					complete = C_QuestLog.IsComplete and C_QuestLog.IsComplete(info.questID) or false }
			end
		end
	else
		for i = 1, (GetNumQuestLogEntries()) do
			local title, level, tag, isHeader, _, isComplete, _, questID = GetQuestLogTitle(i)
			if title then
				t[#t + 1] = { index = i, isHeader = isHeader, title = title, level = level, questID = questID,
					tag = type(tag) == "string" and tag or nil, complete = isComplete == 1 }
			end
		end
	end
	return t
end

-- Retail/Forever know per questID; Classic only for the selected entry, so select it and put the selection back.
local function pushable(entry)
	if C_QuestLog and C_QuestLog.IsPushableQuest then return C_QuestLog.IsPushableQuest(entry.questID) end
	if not (GetQuestLogPushable and SelectQuestLogEntry) then return true end
	local previous = GetQuestLogSelection and GetQuestLogSelection() or 0
	SelectQuestLogEntry(entry.index)
	local ok = GetQuestLogPushable()
	if previous > 0 then SelectQuestLogEntry(previous) end
	return ok and true or false
end

local lastBuild = -math.huge

local function build()
	wipe(groups)
	wipe(allQuests)
	local group
	for _, e in ipairs(logEntries()) do
		if e.isHeader then
			group = { name = e.title, quests = {} }
			groups[#groups + 1] = group
		elseif group and not e.hidden and e.questID and e.questID > 0 and pushable(e) then
			local tagID, tagName = tagOf(e.questID)
			tagName = tagName or e.tag
			local q = { questID = e.questID, title = e.title, level = e.level, group = group, tag = tagName,
				dungeon = (tagID and DUNGEON[tagID]) or (tagName and (tagName == LFG_TYPE_DUNGEON or tagName == LFG_TYPE_RAID)) or false,
				sub = startsAt(e.questID), complete = e.complete }
			group.quests[#group.quests + 1] = q
			allQuests[#allQuests + 1] = q
		end
	end
	local present = {}
	for _, q in ipairs(allQuests) do present[q.questID] = true end
	for id in pairs(checked) do if not present[id] then checked[id] = nil end end
	lastBuild = GetTime()
end

local function ids(quests, only)
	local t = {}
	for _, q in ipairs(quests) do if not only or checked[q.questID] then t[#t + 1] = q.questID end end
	return t
end

---------------------------------------------------------------- window
local win = CreateFrame("Frame", "QuestBufferShareFrame", UIParent, "BasicFrameTemplateWithInset")
win:SetSize(380, 540)
win:SetPoint("CENTER")
win:SetMovable(true)
win:EnableMouse(true)
win:RegisterForDrag("LeftButton")
win:SetScript("OnDragStart", win.StartMoving)
win:SetScript("OnDragStop", win.StopMovingOrSizing)
win.TitleText:SetText(L.title)
tinsert(UISpecialFrames, "QuestBufferShareFrame") -- Esc closes it

local scroll = CreateFrame("ScrollFrame", nil, win, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 12, -32)
scroll:SetPoint("BOTTOMRIGHT", -32, 76)
local list = CreateFrame("Frame", nil, scroll)
list:SetSize(WIDTH, 1)
scroll:SetScrollChild(list)

local function smallButton(parent, label, w)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(w, 20)
	b:SetText(label)
	return b
end

local function getRow(i)
	local row = rows[i]
	if row then return row end
	row = CreateFrame("Button", nil, list)
	row:SetWidth(WIDTH)
	row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
	row.check:SetSize(24, 24)
	row.check:SetPoint("TOPLEFT", 0, 1)
	row.title = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	row.title:SetJustifyH("LEFT")
	row.title:SetWordWrap(false)
	row.sub = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	row.sub:SetJustifyH("LEFT")
	row.sub:SetWordWrap(false)
	row.sel = smallButton(row, L.select, 70)
	row.sel:SetPoint("TOPRIGHT", -74, 0)
	row.shr = smallButton(row, L.share, 70)
	row.shr:SetPoint("TOPRIGHT", 0, 0)

	row.check:SetScript("OnClick", function(self)
		checked[row.quest.questID] = self:GetChecked() or nil
		updateCount()
	end)
	row.sel:SetScript("OnClick", function()
		local all = true
		for _, q in ipairs(row.group.quests) do if not checked[q.questID] then all = false end end
		for _, q in ipairs(row.group.quests) do checked[q.questID] = (not all) or nil end
		layout()
		updateCount()
	end)
	row.shr:SetScript("OnClick", function() ns.share(ids(row.group.quests)) end)
	row:SetScript("OnClick", function()
		if row.group then -- header: collapse / expand
			collapsed[row.group.name] = not collapsed[row.group.name] or nil
			layout()
		else
			checked[row.quest.questID] = not checked[row.quest.questID] or nil
			layout()
			updateCount()
		end
	end)
	row:SetScript("OnEnter", function(self)
		local q = self.quest
		if not q then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(q.title, 1, 1, 1)
		GameTooltip:AddLine(L.zone .. ": " .. q.group.name, 1, 0.82, 0)
		GameTooltip:AddLine(L.level .. ": " .. (q.level or "?") .. (q.tag and (" - " .. q.tag) or ""), 0.8, 0.8, 0.8)
		if q.sub then GameTooltip:AddLine(L.starts .. ": " .. q.sub, 0.8, 0.8, 0.8) end
		GameTooltip:Show()
	end)
	row:SetScript("OnLeave", function() GameTooltip:Hide() end)
	rows[i] = row
	return row
end

local function place(row, y, h, group, quest)
	row.group, row.quest = group, quest
	row:SetHeight(h)
	row:ClearAllPoints()
	row:SetPoint("TOPLEFT", 0, -y)
	row.title:ClearAllPoints()
	row.sub:ClearAllPoints()
	if group then
		row.check:Hide()
		row.sel:Show()
		row.shr:Show()
		row.sub:SetText("")
		row.title:SetPoint("TOPLEFT", 4, -4)
		row.title:SetWidth(WIDTH - 154)
		row.title:SetText(("|cffffd100%s %s (%d)|r"):format(collapsed[group.name] and "[+]" or "[-]", group.name, #group.quests))
	else
		row.check:Show()
		row.check:SetChecked(checked[quest.questID] and true or false)
		row.sel:Hide()
		row.shr:Hide()
		row.title:SetPoint("TOPLEFT", 28, -4)
		row.title:SetWidth(WIDTH - 32)
		row.title:SetText(titleText(quest))
		row.sub:SetPoint("TOPLEFT", 28, -20)
		row.sub:SetWidth(WIDTH - 32)
		row.sub:SetText(quest.sub and (L.starts .. ": " .. quest.sub) or "")
	end
	row:Show()
end

function layout()
	local y, n = 0, 0
	for _, g in ipairs(groups) do
		if #g.quests > 0 then
			n = n + 1
			place(getRow(n), y, ROW_H, g)
			y = y + ROW_H
			if not collapsed[g.name] then
				for _, q in ipairs(g.quests) do
					local h = q.sub and ROW_Q or ROW_H + 2
					n = n + 1
					place(getRow(n), y, h, nil, q)
					y = y + h
				end
			end
		end
	end
	for i = n + 1, #rows do rows[i]:Hide() end
	list:SetHeight(math.max(y, 1))
end

function updateCount()
	local n = #ids(allQuests, true)
	shareSel:SetText(L.shareSelected:format(n))
	shareSel:SetEnabled(n > 0)
end

local function rebuild()
	build()
	layout()
	updateCount()
end

local function footer(label, x, y, w, anchor, onClick)
	local b = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
	b:SetSize(w, 24)
	b:SetPoint(anchor, x, y)
	b:SetText(label)
	b:SetScript("OnClick", onClick)
	return b
end

footer(L.selectAll, 14, 44, 110, "BOTTOMLEFT", function()
	for _, q in ipairs(allQuests) do checked[q.questID] = true end
	layout() updateCount()
end)
footer(L.selectNone, 128, 44, 110, "BOTTOMLEFT", function()
	wipe(checked)
	layout() updateCount()
end)
footer(L.selectDungeon, 242, 44, 110, "BOTTOMLEFT", function()
	wipe(checked)
	for _, q in ipairs(allQuests) do checked[q.questID] = q.dungeon or nil end
	layout() updateCount()
end)
shareSel = footer("", 14, 12, 170, "BOTTOMLEFT", function()
	ns.share(ids(allQuests, true))
	wipe(checked)
	layout() updateCount()
end)
footer(L.shareAll, -14, 12, 170, "BOTTOMRIGHT", function() ns.share(ids(allQuests)) end)

win:SetScript("OnShow", rebuild)
win:Hide()

-- the quest log changes while the window is open (accepting, abandoning, completing): refresh, debounced
local dirty
local events = CreateFrame("Frame")
events:RegisterEvent("QUEST_LOG_UPDATE")
events:SetScript("OnEvent", function()
	-- building on Classic selects log entries, which fires this event again: ignore echoes of our own build
	if not win:IsShown() or dirty or GetTime() - lastBuild < 1 then return end
	dirty = true
	C_Timer.After(0.3, function() dirty = false rebuild() end)
end)

function ns.toggleWindow() win:SetShown(not win:IsShown()) end
