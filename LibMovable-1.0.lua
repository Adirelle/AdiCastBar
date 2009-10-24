--[[
LibMovable-1.0 - Movable frame library
(c) 2009 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local MAJOR, MINOR = 'LibMovable-1.0', 1
local lib, oldMinor = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end
oldMinor = oldMinor or 0

-- Private overlay methods

local function GetFrameLayout(frame)
	local scale, pointFrom, refFrame, pointTo, xOffset, yOffset = frame:GetScale(), frame:GetPoint()
	if refFrame == frame:GetParent() then
		refFrame = nil
	elseif refFrame then
		refFrame = refFrame:GetName()
	end
	return scale, pointFrom, refFrame, pointTo, xOffset, yOffset
end

local function UpdateDatabase(overlay)
	local db, target, defaults = overlay.db, overlay.target, overlay.defaults
	if defaults then
		local scale, pointFrom, refFrame, pointTo, xOffset, yOffset = GetFrameLayout(target)
		db.scale = (scale ~= defaults.scale) and scale or nil
		db.pointFrom = (pointFrom ~= defaults.pointFrom) and pointFrom or nil
		db.refFrame = (refFrame ~= defaults.refFrame) and refFrame or nil
		db.pointTo = (pointTo ~= defaults.pointTo) and pointTo or nil
		db.xOffset = (xOffset ~= defaults.xOffset) and xOffset or nil
		db.yOffset = (yOffset ~= defaults.yOffset) and yOffset or nil
	else
		db.scale, db.pointFrom, db.refFrame, db.pointTo, db.xOffset, db.yOffset = GetFrameLayout(target)
	end
end

local function ApplyLayout(overlay, force)
	local db, target, defaults = overlay.db, overlay.target, overlay.defaults
	if not force and target:IsProtected() and InCombatLockdown() then
		overlay.dirty = true
		return
	else
		overlay.dirty = nil
	end
	target:ClearAllPoints()
	local scale, pointFrom, refFrame, pointTo, xOffset, yOffset =
		db.scale, db.pointFrom, db.refFrame, db.pointTo, db.xOffset, db.yOffset
	if defaults then
		scale = scale or defaults.scale
		pointFrom = pointFrom or defaults.pointFrom
		refFrame = refFrame or defaults.refFrame
		pointTo = pointTo or defaults.pointTo
		xOffset = xOffset or defaults.xOffset
		yOffset = yOffset or defaults.yOffset
	end
	refFrame = refFrame and _G[refFrame] or target:GetParent()
	target:SetScale(scale)	
	target:SetPoint(pointFrom, refFrame, pointTo, xOffset, yOffset)
end

local function StartMoving(overlay)
	if overlay.isMoving then return end
	overlay.target:SetMovable(true)
	overlay.target:StartMoving()
	overlay.isMoving = true
end

local function StopMoving(overlay)
	if not overlay.isMoving then return end
	local db, target, defaults = overlay.db, overlay.target, overlay.defaults
	target:StopMovingOrSizing()
	target:SetMovable(false)
	UpdateDatabase(overlay)
	overlay.isMoving = nil
end

local function ChangeScale(overlay, delta)
	local target = overlay.target
	local oldScale, from, frame, to, oldX, oldY = target:GetScale(), target:GetPoint()			
	local newScale = math.max(math.min(oldScale + 0.1 * delta, 3.0), 0.2)
	if oldScale ~= newScale then
		local newX, newY = oldX / newScale * oldScale, oldY / newScale * oldScale
		target:SetScale(newScale)
		target:SetPoint(from, frame, to, newX, newY)
		UpdateDatabase(overlay)
	end
end

local function ResetLayout(overlay)
	wipe(overlay.db)
	ApplyLayout(overlay)
end

-- Overlay scripts

local scripts = {

	OnEnter = function(overlay)
		GameTooltip:SetOwner(overlay, "ANCHOR_NONE")
		GameTooltip:AddLine(overlay.label)
		GameTooltip:AddLine("Drag this using the left mouse button", 1, 1, 1)
		GameTooltip:AddLine("Use the mousewheel to change the size", 1, 1, 1)
		GameTooltip:AddLine("Hold Alt and right click to reset to defaults", 1, 1, 1)
		GameTooltip:Show()
	end,
	
	OnLeave = function(overlay)
		if GameTooltip:GetOwner() == overlay then
			GameTooltip:Hide()
		end
	end,

	OnShow = function(overlay, force)
		if not force and overlay.target:IsProtected() and InCombatLockdown() then
			StopMoving(overlay)
			overlay:SetBackdropColor(0.5, 0.5, 0.5, 1)
			overlay:EnableMouse(false)
			overlay:EnableMouseWheel(false)
		else
			overlay:SetBackdropColor(0, 1, 0, 1)
			overlay:EnableMouse(true)
			overlay:EnableMouseWheel(true)				
		end
	end,

	OnEvent = function(overlay, event)
		if overlay:IsShown() then
			if event == "PLAYER_REGEN_ENABLED" and overlay.dirty then
				ApplyLayout(overlay, true)
				scripts.OnShow(overlay, true)
			else
				scripts.OnShow(overlay)
			end
		end
	end,
	
	OnMouseDown = function(overlay, button)
		if button == "LeftButton" then
			StartMoving(overlay)
		end
	end,

	OnMouseUp = function(overlay, button)
		if button == "LeftButton" then
			StopMoving(overlay)
		elseif button == "RightButton" and IsAltKeyDown() then
			ResetLayout(overlay)
		end
	end,

	OnMouseWheel = function(overlay, delta)
		ChangeScale(overlay, delta)
	end,
	
}

local function SetScripts(overlay)
	for name, handler in pairs(scripts) do
		overlay:SetScript(name, handler)
	end
end

-- Public API

lib.overlays = lib.overlays or {}
local overlays = lib.overlays

local overlayBackdrop = {
	bgFile = [[Interface\Tooltips\UI-Tooltip-Background]], tile = true, tileSize = 16 
}

function lib.RegisterMovable(key, target, db, label, anchor)
	if overlays[target] then return end
	local overlay = CreateFrame("Frame", nil, UIParent)
	overlays[target] = overlay

	overlay:SetBackdrop(overlayBackdrop)
	overlay:SetBackdropBorderColor(0,0,0,0)	
	overlay:SetAllPoints(anchor or target)
	overlay:Hide()

	label = label or target:GetName()
	if label then
		local text = overlay:CreateFontString(nil, "ARTWORK", "GameFontWhite")
		text:SetAllPoints(overlay)
		text:SetJustifyH("CENTER")
		text:SetJustifyV("MIDDLE")
		text:SetText(label)
	end
	
	overlay.label = label
	overlay.target = target
	overlay.db = db or {}
	overlay.key = key

	local scale, pointFrom, refFrame, pointTo, xOffset, yOffset = GetFrameLayout(target)
	overlay.defaults = {
		scale = scale, 
		pointFrom = pointFrom, 
		refFrame = refFrame,
		pointTo = pointTo,
		xOffset = xOffset, 
		yOffset = yOffset
	}
	end
	
	if target:IsProtected() then
		overlay:RegisterEvent("PLAYER_REGEN_DISABLED")
		overlay:RegisterEvent("PLAYER_REGEN_ENABLED")
	end
	SetScripts(overlay)
	ApplyLayout(overlay)
end

-- Update existing overlays
for target, overlay in pairs(overlays) do
	SetScripts(overlay)
end

function lib.Lock(key)
	for target, overlay in pairs(overlays) do
		if not key or key == overlay.key then
			overlay:Hide()
		end
	end
end

function lib.Unlock(key)
	for target, overlay in pairs(overlays) do
		if not key or key == overlay.key then
			overlay:Show()
		end
	end
end

function lib.IsLocked(key)
	for target, overlay in pairs(overlays) do
		if (not key or key == overlay.key) and overlay:IsShown() then	
			return false
		end
	end
	return true
end

function lib.UpdateLayout(key)
	for target, overlay in pairs(overlays) do
		if not key or key == overlay.key then
			lib.ApplyLayout(overlay)
		end
	end
end

-- Embedding

lib.embeds = lib.embeds or {}
local embeds = lib.embeds

function lib.Embed(target)
	embeds[target] = true
	target.RegisterMovable = lib.RegisterMovable
	target.UpdateMovaleLayout = lib.UpdateLayout
	target.LockMovables = lib.Lock
	target.UnlockMovables = lib.Unlock
	target.AreMovablesLocked = lib.IsLocked
end

for target in pairs(embeds) do
	lib.Embed(target)
end

-- ConfigMode support

CONFIGMODE_CALLBACKS = CONFIGMODE_CALLBACKS or {}
CONFIGMODE_CALLBACKS['Movable Frames'] = function(action)
	if action == "ON" then
		lib.Unlock()
	elseif action == "OFF" then
		lib.Lock()
	end
end

