--[[
AdiCastBar - customized unit cast bars
(c) 2009 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local name, AdiCastBar = ...
_G.AdiCastBar = AdiCastBar
AdiCastBar._G = _G
setmetatable(AdiCastBar, {__index = _G})
setfenv(1, AdiCastBar)

if tekDebug then
	local frame = tekDebug:GetFrame(name)
	function Debug(...)
		return frame:AddMessage(string.join(", ", tostringall(...)):gsub("([:=]), ", "%1"))
	end
else
	function Debug() end
end

