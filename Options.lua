-- Options window: who gets their shared quests accepted without asking, how long "Accept all" keeps going,
-- and the minimap button. Opens from the share window, a right-click on the minimap button, or /qb options.
-- Settings are saved as soon as they change.
local _, ns = ...
local L = ns.L

local opt = CreateFrame("Frame", "QuestBufferOptionsFrame", UIParent, "BasicFrameTemplateWithInset")
opt:SetSize(340, 370)
opt:SetPoint("CENTER", 0, 40)
opt:SetFrameStrata("DIALOG")
opt:SetMovable(true)
opt:EnableMouse(true)
opt:RegisterForDrag("LeftButton")
opt:SetScript("OnDragStart", opt.StartMoving)
opt:SetScript("OnDragStop", opt.StopMovingOrSizing)
opt.TitleText:SetText(L.optionsTitle)
tinsert(UISpecialFrames, "QuestBufferOptionsFrame") -- Esc closes it

local boxes, headings, y = {}, {}, -36

local function refresh()
	for _, box in ipairs(boxes) do box:SetChecked(box.get() and true or false) end
end

local function heading(key)
	local fs = opt:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	fs:SetPoint("TOPLEFT", 16, y)
	fs:SetWidth(308)
	fs:SetJustifyH("LEFT")
	fs.key = key
	fs:SetText(L[key])
	headings[#headings + 1] = fs
	y = y - 24
end

-- A checkbox with its own label. `set` gets the new state; radio-style boxes ignore it and set their value.
local function box(key, tipKey, x, get, set)
	local b = CreateFrame("CheckButton", nil, opt, "UICheckButtonTemplate")
	b:SetSize(24, 24)
	b:SetPoint("TOPLEFT", x, y)
	b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	b.label:SetPoint("LEFT", b, "RIGHT", 2, 0)
	b.key, b.tipKey = key, tipKey
	b.label:SetText(key and L[key] or tipKey)
	b.get = get
	b:SetScript("OnClick", function(self)
		set(self:GetChecked() and true or false)
		refresh()
	end)
	if tipKey then ns.tip(b, function() return (b.key and L[b.key]) or b.staticLabel end, function() return L[b.tipKey] end) end
	boxes[#boxes + 1] = b
	return b
end

heading("optAutoHeading")
for _, o in ipairs({
	{ "optFriends", "optFriendsTip", "autoFriends" },
	{ "optGuild", "optGuildTip", "autoGuild" },
	{ "optLeader", "optLeaderTip", "autoLeader" },
}) do
	local key = o[3]
	box(o[1], o[2], 20, function() return ns.db()[key] end, function(v) ns.db()[key] = v end)
	y = y - 26
end

y = y - 10
heading("optTimeoutHeading")
for i, secs in ipairs({ 5, 10, 15, 30 }) do
	box(nil, "optTimeoutTip", 20 + (i - 1) * 76,
		function() return ns.db().autoTimeout == secs end, function() ns.db().autoTimeout = secs end)
	boxes[#boxes].label:SetText(secs .. " s")
	boxes[#boxes].staticLabel = secs .. " s"
end
y = y - 36

heading("optOtherHeading")
box("optMinimap", "optMinimapTip", 20, function() return not ns.db().hide end, function(v) ns.setMinimap(v) end)
y = y - 30
heading("optLanguageHeading")
for i, language in ipairs({ { "auto", "optLanguageAuto" }, { "en", "optLanguageEnglish" }, { "es", "optLanguageSpanish" } }) do
	local choice, key = language[1], language[2]
	box(key, nil, 20 + (i - 1) * 100,
		function() return (ns.db().language or "auto") == choice end,
		function() ns.db().language = choice; ns.setLanguage(choice) end)
end

local previousRefreshLanguage = ns.refreshLanguage
ns.refreshLanguage = function()
	if previousRefreshLanguage then previousRefreshLanguage() end
	opt.TitleText:SetText(L.optionsTitle)
	for _, fs in ipairs(headings) do fs:SetText(L[fs.key]) end
	for _, b in ipairs(boxes) do
		if b.staticLabel then b.label:SetText(b.staticLabel) else b.label:SetText(L[b.key]) end
		if b.tipKey then ns.tip(b, function() return (b.key and L[b.key]) or b.staticLabel end, function() return L[b.tipKey] end) end
		b:SetChecked(b.get() and true or false)
	end
end

opt:SetScript("OnShow", refresh)
opt:Hide()

function ns.toggleOptions() opt:SetShown(not opt:IsShown()) end
