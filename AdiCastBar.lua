--[[
AdiCastBar - customized unit cast bars
(c) 2009-2013 Adirelle (adirelle@gmail.com)
All rights reserved.
--]]

local addonName, addon = ...

local Movable = LibStub('LibMovable-1.0')

if _G.AdiDebug then
	addon.Debug = _G.AdiDebug:GetSink(addonName)
else
	function addon.Debug() end
end

local function OnEvent(self, event, ...)
	return self[event](self, event, ...)
end

addon.eventFrame = CreateFrame("Frame")
addon.eventFrame:SetScript(OnEvent)

local abstractProto = setmetatable({ Debug = addon.Debug }, getmetatable(addon.eventFrame))
addon.abstractMeta = { __index = abstractProto }

local db

function abstractProto:LM10_Enable()
	db.disabled[self.key] = nil
	self:OnEnable()
end

function abstractProto:LM10_Disable()
	db.disabled[self.key] = true
	self:OnDisable()
end

function abstractProto:LM10_IsEnabled()
	return not db.disabled[self.key]
end

function abstractProto:Initialize(key, width, height, label, from, anchor, to, xOffset, yOffset, ...)
	self.key = key
	self:Hide()
	self:SetScript('OnEvent', OnEvent)

	self:SetSize(widget, height)
	self:SetPoint(from, anchor, to, xOffset, yOffset)

	db[key] = db[key] or {}
	Movable.RegisterMovable(addonName, self, db[key], label)

	self:InitializeWidget(width, heigth, ...)

	if self:LM10_IsEnabled() then
		self:OnEnable()
	end

	return self
end

addon.eventFrame:RegisterEvent('ADDON_LOADED')
function addon.eventFrame:ADDON_LOADED(_, name)
	if name ~= addonName then return end
	self:UnregisterEvent('ADDON_LOADED')

	_G.AdiCastBarDB = _G.AdiCastBarDB or {}
	db = _G.AdiCastBarDB
	db.disabled = db.disabled or {}
	return addon:SpawnAllBars()
end

_G.SLASH_ADICASTBAR1 = "/adicastbar"
_G.SLASH_ADICASTBAR2 = "/acb"
SlashCmdList.ADICASTBAR = function()
	if Movable.IsLocked(addonName) then
		Movable.Unlock(addonName)
	else
		Movable.Lock(addonName)
	end
end
