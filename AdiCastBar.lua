--[[
AdiCastBar - customized unit cast bars
(c) 2009-2013 Adirelle (adirelle@gmail.com)
All rights reserved.
--]]

local addonName, addon = ...

if _G.AdiDebug then
	addon.Debug = _G.AdiDebug:GetSink(addonName)
else
	function addon.Debug() end
end

function addon:OnEvent(event, ...)
	return self[event](self, event, ...)
end

addon.eventFrame = CreateFrame("Frame")
addon.eventFrame:SetScript(addon.OnEvent)
