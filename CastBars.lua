--[[
AdiCastBar - customized unit cast bars
(c) 2009 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

if not AdiCastBar then return end
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
local function FadeOut(self, event, unit, spell, _, castId)
	if unit and unit ~= self.unit then return end
	if castId and castId ~= self.castId then return end
	self.Bar.Spark:Hide()
	if strmatch(event, 'INTERRUPTED') or strmatch(event, 'FAILED') then
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
		FadeOut(self, "TimerUpdate", self.unit, self.castId)
	end
end

local function UpdateDisplay(self, delayed, reversed, color, name, text, texture, startTime, endTime, notInterruptible, castId)
	local latency = self.Latency
	if latency then
		local delay = self.latency[name]
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
	self.castId = castId
	
	self.Bar:SetStatusBarColor(unpack(color))
	self.Bar:SetMinMaxValues(0, endTime-startTime)
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

	if notInterruptible then
		self.Border:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
	else
		self.Border:SetBackdropBorderColor(0, 0, 0, 1)
	end

	self:SetAlpha(1.0)
	self:SetScript('OnUpdate', TimerUpdate)
	self:Show()
end

local function GetCurrentCast(unit, id)
	local name, _, text, texture, startTime, endTime, _, castId, notInterruptible = UnitCastingInfo(unit)
	if startTime and (not id or id == castId) then
		return "CAST", name, text, texture, startTime, endTime, castId, notInterruptible
	end
	name, _, text, texture, startTime, endTime, _, notInterruptible = UnitChannelInfo(unit)
	if startTime then
		return "CHANNEL", name, text, texture, startTime, endTime, 0, notInterruptible	
	end
end

local function Update(self, event, unit, spell, _, eventCastId)
	if unit and unit ~= self.unit then return end
	if self.castId and eventCastId and self.castId ~= eventCastId then return end
	local kind, name, text, texture, startTime, endTime, castId, notInterruptible = GetCurrentCast(self.unit, self.castId)
	if kind then
		local reversed = kind == "CHANNEL"
		local delayed = (event == "UNIT_SPELLCAST_CHANNEL_UPDATE" or event == "UNIT_SPELLCAST_DELAYED")
		UpdateDisplay(self, delayed, reversed, COLORS[kind], name, text, texture, startTime/1000, endTime/1000, notInterruptible, castId)
	elseif self:IsShown() then
		if strmatch(event, '^UNIT_SPELLCAST') then
			FadeOut(self, event, unit, spell, _, eventCastId)
		else
			self:Hide()
		end
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
		Update(self, event, newUnit)
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

	self:RegisterEvent("PLAYER_ENTERING_WORLD", Update)		
	
	self:RegisterEvent("UNIT_SPELLCAST_START", Update)
	self:RegisterEvent("UNIT_SPELLCAST_DELAYED", Update)
	self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START", Update)
	self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", Update)
	self:RegisterEvent('UNIT_SPELLCAST_INTERRUPTIBLE', Update)
	self:RegisterEvent('UNIT_SPELLCAST_NOT_INTERRUPTIBLE', Update)
	
	self:RegisterEvent("UNIT_SPELLCAST_STOP", FadeOut)
	self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP", FadeOut)
	
	self:RegisterEvent("UNIT_SPELLCAST_FAILED", FadeOut)
	self:RegisterEvent("UNIT_SPELLCAST_FAILED_QUIET", FadeOut)
	self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED", FadeOut)
	self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_INTERRUPTED", FadeOut)

	if unit == "player" then
		DisableBlizzardFrame(CastingBarFrame)

	elseif unit == "target" then
		DisableBlizzardFrame(TargetFrameSpellBar)
		self:RegisterEvent("PLAYER_TARGET_CHANGED", Update)
		
	elseif unit == "focus" then
		DisableBlizzardFrame(FocusFrameSpellBar)
		self:RegisterEvent("PLAYER_FOCUS_CHANGED", Update)
		
	elseif unit == "pet" then
		DisableBlizzardFrame(PetCastingBarFrame)
		self:RegisterEvent("UNIT_PET", function(self, event, unit) 
			if unit == "player" then 
				return Update(self, event, "pet") 
			end 
		end)
	end
end
