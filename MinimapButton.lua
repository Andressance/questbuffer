-- Minimap button: the logo in a circle. It is named "...MinimapButton" so button collectors (Minimap Button
-- Button and similar) pick it up and fold it into their own button; without one it sits on the minimap edge.
-- Click opens the share window, right-click the options, drag moves it around the minimap, /qb minimap hides it.
local _, ns = ...
local L = ns.L

local db
local atan2 = math.atan2 or math.atan

local b = CreateFrame("Button", "QuestBufferMinimapButton", Minimap)
b:SetSize(32, 32)
b:SetFrameStrata("MEDIUM")
b:SetFrameLevel(8)
b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
b:RegisterForDrag("LeftButton")
b.icon = b:CreateTexture(nil, "ARTWORK")
b.icon:SetAllPoints()
b.icon:SetTexture("Interface\\AddOns\\QuestBuffer\\Media\\MinimapIcon")
b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local function place()
	local rad = math.rad(db.angle)
	local radius = Minimap:GetWidth() / 2 + 4 -- shortcut: assumes a round minimap, not a square skin
	b:ClearAllPoints()
	b:SetPoint("CENTER", Minimap, "CENTER", math.cos(rad) * radius, math.sin(rad) * radius)
end

b:SetScript("OnClick", function(_, mouse)
	if mouse == "RightButton" then ns.toggleOptions() else ns.toggleWindow() end
end)
b:SetScript("OnDragStart", function(self)
	self:SetScript("OnUpdate", function()
		local mx, my = Minimap:GetCenter()
		local cx, cy = GetCursorPosition()
		local scale = Minimap:GetEffectiveScale()
		db.angle = math.deg(atan2(cy / scale - my, cx / scale - mx))
		place()
	end)
end)
b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
b:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip:SetText("QuestBuffer", 1, 0.82, 0)
	local line1, line2 = ns.statusText() -- what the queue is doing right now
	GameTooltip:AddLine(line1, 1, 1, 1, true)
	if line2 then GameTooltip:AddLine(line2, 1, 1, 1, true) end
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine(L.minimapClick, 0.8, 0.8, 0.8)
	GameTooltip:AddLine(L.minimapRight, 0.8, 0.8, 0.8)
	GameTooltip:AddLine(L.minimapDrag, 0.8, 0.8, 0.8)
	GameTooltip:AddLine(L.minimapHide, 0.8, 0.8, 0.8)
	GameTooltip:Show()
end)
b:SetScript("OnLeave", function() GameTooltip:Hide() end)

function ns.setMinimap(show)
	db.hide = (not show) or nil
	b:SetShown(show)
end

function ns.toggleMinimap() ns.setMinimap(db.hide and true or false) end

-- saved variables only exist once ADDON_LOADED fires
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, _, name)
	if name ~= "QuestBuffer" then return end
	db = ns.db()
	db.angle = db.angle or 215
	place()
	b:SetShown(not db.hide)
end)
