-- Options window: who gets their shared quests accepted without asking, how long "Accept all" keeps going,
-- and the minimap button. Opens from the share window, a right-click on the minimap button, or /qb options.
-- Settings are saved as soon as they change.
local _, ns = ...
local L = ns.L

local opt = CreateFrame("Frame", "QuestBufferOptionsFrame", UIParent, "BasicFrameTemplateWithInset")
opt:SetSize(340, 330)
opt:SetPoint("CENTER", 0, 40)
opt:SetFrameStrata("DIALOG")
opt:SetMovable(true)
opt:EnableMouse(true)
opt:RegisterForDrag("LeftButton")
opt:SetScript("OnDragStart", opt.StartMoving)
opt:SetScript("OnDragStop", opt.StopMovingOrSizing)
opt.TitleText:SetText(L.optionsTitle)
tinsert(UISpecialFrames, "QuestBufferOptionsFrame") -- Esc closes it

local boxes, y = {}, -36

local function refresh()
	for _, box in ipairs(boxes) do box:SetChecked(box.get() and true or false) end
end

local function heading(text)
	local fs = opt:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	fs:SetPoint("TOPLEFT", 16, y)
	fs:SetWidth(308)
	fs:SetJustifyH("LEFT")
	fs:SetText(text)
	y = y - 24
end

-- A checkbox with its own label. `set` gets the new state; radio-style boxes ignore it and set their value.
local function box(label, tipText, x, get, set)
	local b = CreateFrame("CheckButton", nil, opt, "UICheckButtonTemplate")
	b:SetSize(24, 24)
	b:SetPoint("TOPLEFT", x, y)
	b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	b.label:SetPoint("LEFT", b, "RIGHT", 2, 0)
	b.label:SetText(label)
	b.get = get
	b:SetScript("OnClick", function(self)
		set(self:GetChecked() and true or false)
		refresh()
	end)
	ns.tip(b, label, tipText)
	boxes[#boxes + 1] = b
	return b
end

heading(L.optAutoHeading)
for _, o in ipairs({
	{ L.optFriends, L.optFriendsTip, "autoFriends" },
	{ L.optGuild, L.optGuildTip, "autoGuild" },
	{ L.optLeader, L.optLeaderTip, "autoLeader" },
}) do
	local key = o[3]
	box(o[1], o[2], 20, function() return ns.db()[key] end, function(v) ns.db()[key] = v end)
	y = y - 26
end

y = y - 10
heading(L.optTimeoutHeading)
for i, secs in ipairs({ 5, 10, 15, 30 }) do
	box(secs .. " s", L.optTimeoutTip, 20 + (i - 1) * 76,
		function() return ns.db().autoTimeout == secs end, function() ns.db().autoTimeout = secs end)
end
y = y - 36

heading(L.optOtherHeading)
box(L.optMinimap, L.optMinimapTip, 20, function() return not ns.db().hide end, function(v) ns.setMinimap(v) end)

opt:SetScript("OnShow", refresh)
opt:Hide()

function ns.toggleOptions() opt:SetShown(not opt:IsShown()) end
