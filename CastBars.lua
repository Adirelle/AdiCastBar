--[[
AdiCastBar - customized unit cast bars
(c) 2009 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

if not AdiCastBar then return end
setfenv(1, AdiCastBar)

local COLORS = {
	CAST = { 0, 1, 0 },
	CHANNEL = { 0.3, 0.5, 1 },
	INTERRUPTED = { 1, 0, 0 },
}

local GetTime = GetTime

local function FadingOut(self)
	local now = GetTime()
	local alpha = 1.0 - (now - self.endTime)
	if alpha > 0 then 
		self:SetAlpha(alpha)
	else
		self:SetScript('OnUpdate', nil)
		self:Hide()
	end
end

local strmatch = string.match
local function FadeOut(self, event, unit)
	if (unit and unit ~= self.unit) or not self:IsShown() or self.fadingOut then return end
	self.Bar.Spark:Hide()
	if strmatch(event, 'INTERRUPTED') then
		self.Bar:SetStatusBarColor(unpack(COLORS.INTERRUPTED))
	else
		self.Bar:SetValue(self.reversed and 0 or (self.endTime - self.startTime))
	end
	self.endTime = GetTime()
	self.fadingOut = true
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
		FadeOut(self, "TimerUpdate", self.unit)
	end
end

local function UpdateDisplay(self, delayed, reversed, color, name, text, texture, startTime, endTime, notInterruptible)
	local latency = self.Latency
	if latency then
		local delay = self.latency
		if delay then
			startTime = startTime - delay
			endTime = endTime - delay
		
			latency:ClearAllPoints()
			latency:SetPoint(reversed and "LEFT" or "RIGHT", self.Bar)
			latency:SetWidth(self.Bar:GetWidth() * delay / (endTime - startTime))
			latency:Show()
		else
			latency:Hide()
		end
	end
	
	if not delayed then
		self.startTime = startTime
		self.delay = nil
	else
		self.delay = startTime - self.startTime
	end
	self.endTime = endTime
	self.reversed = reversed
	
	self.Bar:SetStatusBarColor(unpack(color))
	self.Bar:SetMinMaxValues(0, endTime-startTime)
	self.Bar.Spark:Show()
	
	text = text or name
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

	if notInterruptible then
		self.Border:SetBackdropBorderColor(0.7, 0.7, 0.7, 1)
	else
		self.Border:SetBackdropBorderColor(0, 0, 0, 1)
	end

	self:SetAlpha(1.0)
	self:SetScript('OnUpdate', TimerUpdate)
	self.fadingOut = nil

	self:Show()
	
	return true
end

local function Update(self, event, unit)
	if unit and unit ~= self.unit then return end
	local delayed = (event == "UNIT_SPELLCAST_CHANNEL_UPDATE" or event == "UNIT_SPELLCAST_DELAYED")
	local color, reversed = COLORS.CAST, false
	local name, _, text, texture, startTime, endTime, _, _, notInterruptible = UnitCastingInfo(self.unit)
	if not startTime then
		name, _, text, texture, startTime, endTime, _, _, notInterruptible = UnitChannelInfo(self.unit)
		color, reversed = COLORS.CHANNEL, true
	end
	if startTime then
		UpdateDisplay(self, delayed, reversed, color, name, text, texture, startTime/1000, endTime/1000, notInterruptible)
	elseif self:IsShown() then
		if strmatch(event, '^UNIT_SPELLCAST') then
			FadeOut(self, event, unit)
		else
			self:Hide()
		end
	end
end 

local function LatencyStart(self, event, unit)
	if unit and unit ~= self.unit then return end
	self.latencyStart = GetTime()
	self.latency = nil
	self.Latency:Hide()
end

local function LatencyEnd(self, event, unit, spell)
	if unit and unit ~= self.unit then return end
	if self.latencyStart then
		self.latency = GetTime() - self.latencyStart
		self.latencyStart = nil
	end
end

local lae = LibStub('LibAdiEvent-1.0')
function EnableCastBar(self)
	if not self.unit then return print('Ignoring castbar, no unit') end
	lae.Embed(self)
	
	if self.Latency then
		self:RegisterEvent("UNIT_SPELLCAST_SENT", LatencyStart)
		self:RegisterEvent("UNIT_SPELLCAST_START", LatencyEnd)
		self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START", LatencyEnd)
	end

	self:RegisterEvent("PLAYER_ENTERING_WORLD", Update)		
	
	self:RegisterEvent("UNIT_SPELLCAST_START", Update)
	self:RegisterEvent("UNIT_SPELLCAST_DELAYED", Update)
	self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START", Update)
	self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", Update)
	self:RegisterEvent('UNIT_SPELLCAST_INTERRUPTIBLE', Update)
	self:RegisterEvent('UNIT_SPELLCAST_NOT_INTERRUPTIBLE', Update)
	
	self:RegisterEvent("UNIT_SPELLCAST_STOP", FadeOut)
	self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP", FadeOut)
	
	self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED", FadeOut)
	self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_INTERRUPTED", FadeOut)

	if self.unit == "player" then
		CastingBarFrame.RegisterEvent = nothing
		CastingBarFrame:UnregisterAllEvents()
		CastingBarFrame.Show = CastingBarFrame.Hide
		CastingBarFrame:Hide()
	elseif self.unit == "target" then
		self:RegisterEvent("PLAYER_TARGET_CHANGED", Update)
	elseif self.unit == "focus" then
		self:RegisterEvent("PLAYER_FOCUS_CHANGED", Update)
	end
end

