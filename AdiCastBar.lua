--[[
AdiCastBar - customized unit cast bars
(c) 2009-2012 Adirelle (adirelle@gmail.com)
All rights reserved.
--]]

local name, AdiCastBar = ...
_G.AdiCastBar = AdiCastBar
AdiCastBar._G = _G
setmetatable(AdiCastBar, {__index = _G})
setfenv(1, AdiCastBar)

if AdiDebug then
	Debug = AdiDebug:GetSink(name)
else
	function Debug() end
end

