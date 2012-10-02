--[[
AdiCastBar - customized unit cast bars
(c) 2009-2012 Adirelle (adirelle@gmail.com)
All rights reserved.
--]]

local name, AdiCastBar = ...

if _G.AdiDebug then
	AdiCastBar.Debug = _G.AdiDebug:GetSink(name)
else
	function AdiCastBar.Debug() end
end
