--[[
AdiCastBar - customized unit cast bars
(c) 2009 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local _, AdiCastBar = ...
setfenv(1, AdiCastBar)

local COLORS = {
	CAST = { 1.0, 0.7, 0.0 },
	CHANNEL = { 0.0, 1.0, 0.0 },
	INTERRUPTED = { 1.0, 0.0, 0.0 },
}

local GetTime = GetTime

local function FadingOut(self)
	local now = GetTime()
	local alpha = self.fadeDuration - (now - self.endTime)
	if alpha > 0 then 
		self:SetAlpha(math.min(alpha, 1.0))
	else
		self:SetScript('OnUpdate', nil)
		self:Hide()
	end
end

local strmatch = string.match
local function FadeOut(self, failed)
	Debug('FadeOut', failed)	
	self.Bar.Spark:Hide()
	if failed then
		self.Bar:SetStatusBarColor(unpack(COLORS.INTERRUPTED))
		self.fadeDuration = 1.5
	else
		self.Bar:SetValue(self.reversed and 0 or (self.endTime - self.startTime))
		self.fadeDuration = 1.0
	end
	self.endTime = GetTime()
	self.castId = nil
	self:SetScript('OnUpdate', FadingOut)	
end 

local function TimerUpdate(self)
	local now = GetTime()
	if self.reversed then
		self.Bar:SetValue(self.endTime - now)
	else
		self.Bar:SetValue(now - self.startTime)
	end
	if now > self.endTime then
		return FadeOut(self)
	end
end

local function SetNotInterruptible(self, notInterruptible)
	if notInterruptible then
		self.Border:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
	else
		self.Border:SetBackdropBorderColor(0, 0, 0, 1)
	end
end

local function SetTime(self, startTime, endTime, delayed)
	if not delayed then
		self.startTime = startTime
		self.delay = nil
	else
		self.delay = startTime - self.startTime
	end
	self.endTime = endTime	
	self.Bar:SetMinMaxValues(0, endTime-startTime)
end

local function StartCast(self, reversed, color, name, text, texture, startTime, endTime, notInterruptible, castId)
	local latency = self.Latency
	if latency then
		local delay = self.latency[name]
		if delay then
			startTime = startTime - delay
			endTime = endTime - delay
		
			latency:ClearAllPoints()
			latency:SetPoint(reversed and "LEFT" or "RIGHT", self.Bar)
			latency:SetWidth(self.Bar:GetWidth() * math.min(delay / (endTime - startTime), 1.0))
			latency:Show()
		else
			latency:Hide()
		end
	end
	
	self.reversed = reversed
	self.castId = castId
	
	self.Bar:SetStatusBarColor(unpack(color))
	self.Bar.Spark:Show()
	
	text = name or text
	if text then
		self.Text:SetText(text)
		self.Text:Show()
	else
		self.Text:Hide()
	end 

	if texture then
		self.Icon:SetTexture(texture)
		self.Icon:Show()
	else
		self.Icon:Hide()
	end

	SetTime(self, startTime, endTime)
	SetNotInterruptible(self, notInterruptible)

	self:SetAlpha(1.0)
	self:SetScript('OnUpdate', TimerUpdate)
	self:Show()
end

local function UNIT_SPELLCAST_START(self, event, unit, _, _, castId)
	if unit ~= self.unit then return end
	local name, _, text, texture, startTime, endTime, _, castId, notInterruptible = UnitCastingInfo(unit)
	Debug(self, event, unit, castId, rank, name, text, texture, startTime, endTime, castId, notInterruptible)
	return StartCast(self, false, COLORS.CAST, name, text, texture, startTime/1000, endTime/1000, notInterruptible, castId)
end

local function UNIT_SPELLCAST_DELAYED(self, event, unit, _, _, castId)
	if unit ~= self.unit or castId ~= self.castId then return end
	local _, _, _, _, startTime, endTime = UnitCastingInfo(unit)
	Debug(self, event, unit, castId, startTime, endTime)
	return SetTime(self, startTime/1000, endTime/1000, true)
end

local function UNIT_SPELLCAST_INTERRUPTIBLE(self, event, unit)
	if unit ~= self.unit or not self.castId then return end
	Debug(self, event, unit)
	return SetNotInterruptible(self, false)
end

local function UNIT_SPELLCAST_NOT_INTERRUPTIBLE(self, event, unit)
	if unit ~= self.unit or not self.castId then return end
	Debug(self, event, unit)
	return SetNotInterruptible(self, true)
end

local function UNIT_SPELLCAST_STOP(self, event, unit, _, _, castId)
	if unit ~= self.unit or castId ~= self.castId then return end
	Debug(self, event, unit, castId)
	return FadeOut(self)
end

local function UNIT_SPELLCAST_INTERRUPTED(self, event, unit, _, _, castId)
	if unit ~= self.unit or castId ~= self.castId then return end
	Debug(self, event, unit, castId)
	return FadeOut(self, true)
end

local UNIT_SPELLCAST_FAILED = UNIT_SPELLCAST_INTERRUPTED
local UNIT_SPELLCAST_FAILED_QUIET = UNIT_SPELLCAST_INTERRUPTED
 
local function UNIT_SPELLCAST_CHANNEL_START(self, event, unit)
	if unit ~= self.unit then return end
	local name, _, text, texture, startTime, endTime, _, notInterruptible = UnitChannelInfo(unit)
	Debug(self, event, unit, name, text, texture, startTime, endTime, notInterruptible)
	return StartCast(self, true, COLORS.CHANNEL, name, text, texture, startTime/1000, endTime/1000, notInterruptible, "CHANNEL")
end

local function UNIT_SPELLCAST_CHANNEL_UPDATE(self, event, unit)
	if unit ~= self.unit or self.castId ~= "CHANNEL" then return end
	local _, _, _, _, startTime, endTime = UnitChannelInfo(unit)
	Debug(self, event, unit, startTime, endTime)
	return SetTime(self, startTime/1000, endTime/1000, true)	
end

local function UNIT_SPELLCAST_CHANNEL_STOP(self, event, unit)
	if unit ~= self.unit or self.castId ~= "CHANNEL" then return end
	Debug(self, event, unit)
	return FadeOut(self)
end

local function UNIT_SPELLCAST_CHANNEL_INTERRUPTED(self, event, unit)
	if unit ~= self.unit or self.castId ~= "CHANNEL" then return end
	Debug(self, event, unit)
	return FadeOut(self, true)
end

local function PLAYER_ENTERING_WORLD(self, event)
	local unit = self.unit
	Debug(self, event, unit, "casting:", UnitCastingInfo(unit), "channeling:", (UnitChannelInfo(unit)))
	if UnitCastingInfo(unit) then
		return UNIT_SPELLCAST_START(self, event, unit)
	elseif UnitChannelInfo(unit) then
		return UNIT_SPELLCAST_CHANNEL_START(self, event, unit)
	elseif self:IsShown() then
		self.castId = nil
		return self:Hide()
	end
end

local function LatencyStart(self, event, unit, spell)
	if unit and unit ~= self.unit then return end
	self.latency[spell] = nil
	self.latencyStart[spell] = GetTime()
end

local function LatencyEnd(self, event, unit, spell)
	if unit and unit ~= self.unit then return end
	local start = self.latencyStart[spell] 
	if start then
		self.latency[spell] = GetTime() - start
		self.latencyStart[spell] = nil
	end
end

local function UpdateVehicleState(self, event, unit)
	if unit and unit ~= 'player' then return end
	local newUnit = UnitHasVehicleUI('player') and 'vehicle' or 'player'
	if newUnit ~= self.unit then
		self.unit = newUnit
		return PLAYER_ENTERING_WORLD(self, event)
	end
end

local function noop() end
local function DisableBlizzardFrame(frame)
	frame.RegisterEvent = noop
	frame.Show = noop
	frame:UnregisterAllEvents()
	frame:Hide()
end

local lae = LibStub('LibAdiEvent-1.0')
function EnableCastBar(self)
	local unit = self.unit
	if not unit then return print('Ignoring castbar, no unit') end
	lae.Embed(self)

	if self.Latency then
		self.latency = {}
		self.latencyStart = {}
		self:RegisterEvent("UNIT_SPELLCAST_SENT", LatencyStart)
		self:RegisterEvent("UNIT_SPELLCAST_START", LatencyEnd)
		self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START", LatencyEnd)
	end
	
	if unit == "player" then			
		self:RegisterEvent("PLAYER_ENTERING_WORLD", UpdateVehicleState)		
		self:RegisterEvent("UNIT_ENTERED_VEHICLE", UpdateVehicleState)		
		self:RegisterEvent("UNIT_EXITED_VEHICLE", UpdateVehicleState)		
	end

	self:RegisterEvent("PLAYER_ENTERING_WORLD", PLAYER_ENTERING_WORLD)		
	
	self:RegisterEvent("UNIT_SPELLCAST_START", UNIT_SPELLCAST_START)
	self:RegisterEvent("UNIT_SPELLCAST_DELAYED", UNIT_SPELLCAST_DELAYED)
	self:RegisterEvent('UNIT_SPELLCAST_INTERRUPTIBLE', UNIT_SPELLCAST_INTERRUPTIBLE)
	self:RegisterEvent('UNIT_SPELLCAST_NOT_INTERRUPTIBLE', UNIT_SPELLCAST_NOT_INTERRUPTIBLE)	
	self:RegisterEvent("UNIT_SPELLCAST_STOP", UNIT_SPELLCAST_STOP)
	self:RegisterEvent("UNIT_SPELLCAST_FAILED", UNIT_SPELLCAST_FAILED)
	self:RegisterEvent("UNIT_SPELLCAST_FAILED_QUIET", UNIT_SPELLCAST_FAILED_QUIET)
	self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED", UNIT_SPELLCAST_INTERRUPTED)
	
	self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START", UNIT_SPELLCAST_CHANNEL_START)
	self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", UNIT_SPELLCAST_CHANNEL_UPDATE)
	self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP", UNIT_SPELLCAST_CHANNEL_STOP)
	self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_INTERRUPTED", UNIT_SPELLCAST_CHANNEL_INTERRUPTED)

	if unit == "player" then
		DisableBlizzardFrame(CastingBarFrame)

	elseif unit == "target" then
		DisableBlizzardFrame(TargetFrameSpellBar)
		self:RegisterEvent("PLAYER_TARGET_CHANGED", PLAYER_ENTERING_WORLD)
		
	elseif unit == "focus" then
		DisableBlizzardFrame(FocusFrameSpellBar)
		self:RegisterEvent("PLAYER_FOCUS_CHANGED", PLAYER_ENTERING_WORLD)
		
	elseif unit == "pet" then
		DisableBlizzardFrame(PetCastingBarFrame)
		self:RegisterEvent("UNIT_PET", function(self, event, unit) 
			if unit == "player" then 
				return PLAYER_ENTERING_WORLD(self, event, "pet") 
			end 
		end)
	end
end
