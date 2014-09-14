--[[
AdiCastBar - customized unit cast bars
(c) 2009-2014 Adirelle (adirelle@gmail.com)
All rights reserved.
--]]

local _, addon = ...

local _G = _G
local CastingBarFrame = _G.CastingBarFrame
local DebuffTypeColor = _G.DebuffTypeColor
local FocusFrameSpellBar = _G.FocusFrameSpellBar
local GetCVar = _G.GetCVar
local GetCVarBool = _G.GetCVarBool
local GetSpellInfo = _G.GetSpellInfo
local GetTalentInfo = _G.GetTalentInfo
local GetTime = _G.GetTime
local IsLoggedIn = _G.IsLoggedIn
local IsSpellKnown = _G.IsSpellKnown
local min = _G.min
local pairs = _G.pairs
local PetCastingBarFrame = _G.PetCastingBarFrame
local print = _G.print
local select = _G.select
local tonumber = _G.tonumber
local tostring = _G.tostring
local type = _G.type
local UnitCastingInfo = _G.UnitCastingInfo
local UnitChannelInfo = _G.UnitChannelInfo
local UnitDebuff = _G.UnitDebuff
local UnitHasVehicleUI = _G.UnitHasVehicleUI
local UnitIsPVP = _G.UnitIsPVP
local unpack = _G.unpack

local COLORS = {
	CAST = { 1.0, 0.7, 0.0 },
	CHANNEL = { 0.0, 1.0, 0.0 },
	INTERRUPTED = { 1.0, 0.0, 0.0 },
}

-- Tick period of channeled spells, defaults to 1
local NUM_TICKS = {
	[    10] =  8, -- Blizzard
	[   689] =  6, -- Drain Life
	[   740] =  4, -- Tranquility
	[   755] =  6, -- Health Funnel
	[  1120] =  6, -- Drain Soul
	[  1949] = 14, -- Hellfire
	[  4629] =  6, -- Rain of Fire
	[  5143] =  5, -- Arcane Missiles
	[ 12051] =  3, -- Evocation
	[ 15407] =  3, -- Mind Flay
	[ 16914] = 10, -- Hurricane
	[ 32000] =  5, -- Mind Sear
	[ 47540] =  2, -- Penance
	[ 64843] =  4, -- Divine Hymn
	[ 64901] =  4, -- Hymn of Hope
	[103103] =  4, -- Malefic Grasp
	[106996] = 10, -- Astral Storm
	[108371] =  6, -- Harvest Life
	[113656] =  4, -- Fists of fury
	[115175] =  8, -- Soothing Mist
	[117952] =  6, -- Crackling Jade Lightning
	[120360] = 15, -- Barrage
	[127663] =  4, -- Astral Communion
	[129197] =  3, -- Mind Flay (insanity)
}

-- Mana Tea is a special case
do
	local manaTeaCharge = GetSpellInfo(115867)
	NUM_TICKS[115294] = function(unit)
		return select(4, UnitBuff(unit, manaTeaCharge)) or 0
	end
end

-- Channeled spells that have a first instant tick
local INSTANT_TICK = {
	[  1949] = true, -- Hellfire
	[ 12051] = true, -- Evocation
	[ 47540] = true, -- Penance
	[113656] = true, -- Firsts of Fury
	[115175] = true, -- Soothing Mist
}

-- Channeled spells that gain more ticks thanks to haste
local GAIN_TICKS = {
	[64843] = true, -- Divine Hymn
	[64901] = true, -- Hymn of Hope
}

local GetTime = GetTime

local barProto = setmetatable({}, addon.abstractMeta)
local barMeta = { __index = barProto }
addon.castBarProto = barProto

function barProto:FadingOut()
	local now = GetTime()
	local alpha = self.fadeDuration - (now - self.endTime)
	if alpha > 0 then
		self:SetAlpha(min(alpha, 1.0))
	else
		self:SetScript('OnUpdate', nil)
		self:Hide()
	end
end

function barProto:FadeOut(failed)
	self:Debug('FadeOut', failed)
	if self.Latency then
		self.Latency:Hide()
	end
	if self.Ticks then
		self:HideTicks()
	end
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
	self:SetScript('OnUpdate', self.FadingOut)
end

function barProto:TimerUpdate()
	local now = GetTime()
	if self.reversed then
		self.Bar:SetValue(self.endTime - now)
	else
		self.Bar:SetValue(now - self.startTime)
	end
	if now > self.endTime then
		return self:FadeOut()
	end
end

function barProto:SetNotInterruptible(notInterruptible)
	if notInterruptible then
		self.Border:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
		self.Shield:Show()
	else
		self.Border:SetBackdropBorderColor(0, 0, 0, 1)
		self.Shield:Hide()
	end
end

function barProto:ShowTicks(numTicks, instantTick, addTicks, haste)
	if not self.Ticks then return end
	self:HideTicks()
	numTicks = numTicks or 0
	self.numTicks, self.instantTick, self.addTicks, self.haste = numTicks, instantTick, addTicks, haste
	if numTicks > 0 then
		if addTicks then
			numTicks = floor(numTicks * haste + 0.5)
		end
		local totalNum = numTicks
		if instantTick then
			totalNum = totalNum + 1
		end
		local offset = self.Bar:GetWidth() / numTicks
		for i = 1, totalNum do
			local tick = self:GetTick(i)
			tick:SetPoint("BOTTOM", self.Bar, "TOPLEFT", (i-1) * offset, -3)
			tick:Show()
		end
	end
end

function barProto:SetTime(startTime, endTime, delayed)
	if not delayed or startTime - self.startTime < 1e-2 or self.tickPeriod then
		self.startTime = startTime
		self.delay = nil
	else
		self.delay = startTime - self.startTime
	end
	self.endTime = endTime

	local duration = endTime - startTime
	self.Bar:SetMinMaxValues(0, duration)
end

function barProto:StartCast(reversed, color, name, text, texture, startTime, endTime, notInterruptible, castId)
	local latency = self.Latency
	if latency and not reversed then
		local delay
		if GetCVarBool("reducedLagTolerance") then
			delay = tonumber(GetCVar("MaxSpellStartRecoveryOffset")) / 1000
		else
			delay = self.latency[name]
		end
		if delay then
			latency:ClearAllPoints()
			latency:SetPoint("RIGHT", self.Bar)
			latency:SetWidth(self.Bar:GetWidth() * min(delay / (endTime - startTime), 1.0))
			latency:Show()
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

	self:SetTime(startTime, endTime)
	self:SetNotInterruptible(notInterruptible)

	self:SetAlpha(1.0)
	self:SetScript('OnUpdate', self.TimerUpdate)
	self:Show()
end

function barProto:UNIT_SPELLCAST_START(event, unit, spell, _, castId)
	local name, rank, text, texture, startTime, endTime, _, castId, notInterruptible = UnitCastingInfo(unit)
	self:Debug(event, unit, castId, rank, name, text, texture, startTime, endTime, castId, notInterruptible)
	self:LatencyEnd(event, unit, spell)
	return self:StartCast(false, COLORS.CAST, name, text, texture, startTime/1000, endTime/1000, notInterruptible, castId)
end

function barProto:UNIT_SPELLCAST_DELAYED(event, unit, _, _, castId)
	if castId ~= self.castId then return end
	local _, _, _, _, startTime, endTime = UnitCastingInfo(unit)
	self:Debug(event, unit, castId, startTime, endTime)
	return self:SetTime(startTime/1000, endTime/1000, true)
end

function barProto:UNIT_SPELLCAST_INTERRUPTIBLE(event, unit)
	if not self.castId then return end
	self:Debug(event, unit)
	return self:SetNotInterruptible(false)
end

function barProto:UNIT_SPELLCAST_NOT_INTERRUPTIBLE(event, unit)
	if not self.castId then return end
	self:Debug(event, unit)
	return self:SetNotInterruptible(true)
end

function barProto:UNIT_SPELLCAST_STOP(event, unit, _, _, castId)
	if castId ~= self.castId then return end
	self:Debug(event, unit, castId)
	return self:FadeOut()
end

function barProto:UNIT_SPELLCAST_INTERRUPTED(event, unit, _, _, castId)
	if castId ~= self.castId then return end
	self:Debug(event, unit, castId)
	return self:FadeOut(true)
end

barProto.UNIT_SPELLCAST_FAILED = barProto.UNIT_SPELLCAST_INTERRUPTED
barProto.UNIT_SPELLCAST_FAILED_QUIET = barProto.UNIT_SPELLCAST_INTERRUPTED

function barProto:UNIT_SPELLCAST_CHANNEL_START(event, unit, spell, _, _, spellID)
	local name, _, text, texture, startTime, endTime, _, notInterruptible = UnitChannelInfo(unit)
	self:Debug(event, unit, name, text, texture, startTime, endTime, notInterruptible)
	self:LatencyEnd(event, unit, spell)
	self:StartCast(true, COLORS.CHANNEL, name, text, texture, startTime/1000, endTime/1000, notInterruptible, "CHANNEL")
	local numTicks = NUM_TICKS[spellID]
	if type(numTicks) == "function" then numTicks = numTicks(unit) end
	return self:ShowTicks(numTicks, INSTANT_TICK[spellID], GAIN_TICKS[spellID], (1+UnitSpellHaste(unit)/100))
end

function barProto:UNIT_SPELLCAST_CHANNEL_UPDATE(event, unit)
	if self.castId ~= "CHANNEL" then return end
	local _, _, _, _, startTime, endTime = UnitChannelInfo(unit)
	self:Debug(event, unit, startTime, endTime)
	self:SetTime(startTime/1000, endTime/1000, true)
	return self:ShowTicks(self.numTicks, self.instantTick, self.addTicks, self.haste)
end

function barProto:UNIT_SPELLCAST_CHANNEL_STOP(event, unit)
	if self.castId ~= "CHANNEL" then return end
	self:Debug(event, unit)
	return self:FadeOut()
end

function barProto:UNIT_SPELLCAST_CHANNEL_INTERRUPTED(event, unit)
	if self.castId ~= "CHANNEL" then return end
	self:Debug(event, unit)
	return self:FadeOut(true)
end

local function GetActualUnit(unit)
	if unit == "player" then
		return UnitHasVehicleUI('player') and 'vehicle' or 'player'
	elseif unit == "pet" then
		return UnitHasVehicleUI('player') and 'player' or 'pet'
	else
		return unit
	end
end

function barProto:PLAYER_ENTERING_WORLD(event)
	local unit = self.unit
	if unit ~= GetActualUnit(self.realUnit) then
		self:OnDisable()
		self:OnEnable()
		return
	end
	self:Debug(event, unit, "casting:", UnitCastingInfo(unit), "channeling:", (UnitChannelInfo(unit)))
	if UnitCastingInfo(unit) then
		return self:UNIT_SPELLCAST_START(event, unit)
	elseif UnitChannelInfo(unit) then
		return self:UNIT_SPELLCAST_CHANNEL_START(event, unit)
	elseif self:IsShown() then
		self.castId = nil
		self:Hide()
	end
end

function barProto:UNIT_PET(event, unit)
	return self:PLAYER_ENTERING_WORLD(self, event)
end

function barProto:UNIT_SPELLCAST_SENT(event, unit, spell)
	self.latency[spell] = nil
	self.latencyStart[spell] = GetTime()
end

function barProto:LatencyEnd(event, unit, spell)
	if self.latency then
		local start = self.latencyStart[spell]
		if start then
			self.latency[spell] = GetTime() - start
			self.latencyStart[spell] = nil
		end
	end
end

function barProto:UNIT_ENTERED_VEHICLE(event, unit)
	if unit == "player" then
		return self:PLAYER_ENTERING_WORLD(event)
	end
end
barProto.UNIT_EXITED_VEHICLE = barProto.UNIT_ENTERED_VEHICLE

local function noop() end
local function DisableBlizzardFrame(frame)
	frame.RegisterEvent = noop
	frame.Show = noop
	frame:UnregisterAllEvents()
	frame:Hide()
end

function barProto:OnEnable()
	local unit = GetActualUnit(self.realUnit)
	self.unit = unit

	self:RegisterEvent("PLAYER_ENTERING_WORLD")

	if self.realUnit == 'player' or self.realUnit == 'pet' then
		self:RegisterUnitEvent("UNIT_ENTERED_VEHICLE", "player")
		self:RegisterUnitEvent("UNIT_EXITED_VEHICLE", "player")
	end

	self:RegisterUnitEvent("UNIT_SPELLCAST_START", unit)
	self:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED", unit)
	self:RegisterUnitEvent('UNIT_SPELLCAST_INTERRUPTIBLE', unit)
	self:RegisterUnitEvent('UNIT_SPELLCAST_NOT_INTERRUPTIBLE', unit)
	self:RegisterUnitEvent("UNIT_SPELLCAST_STOP", unit)
	self:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", unit)
	self:RegisterUnitEvent("UNIT_SPELLCAST_FAILED_QUIET", unit)
	self:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", unit)

	self:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", unit)
	self:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", unit)
	self:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", unit)
	self:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_INTERRUPTED", unit)

	if self.latency then
		self:RegisterUnitEvent("UNIT_SPELLCAST_SENT", unit)
	end

	if unit == "target" then
		self.PLAYER_TARGET_CHANGED = self.PLAYER_ENTERING_WORLD
		self:RegisterEvent("PLAYER_TARGET_CHANGED")

	elseif unit == "focus" then
		self.PLAYER_FOCUS_CHANGED = self.PLAYER_ENTERING_WORLD
		self:RegisterEvent("PLAYER_FOCUS_CHANGED")

	elseif self.realUnit == "pet" then
		self:RegisterUnitEvent("UNIT_PET", "player")
	end

	if IsLoggedIn() then
		self:PLAYER_ENTERING_WORLD('OnEnable')
	end
end

function barProto:OnDisable()
	self:UnregisterAllEvents()
	self:Hide()
end

function addon:SpawnCastBar(unit, width, height, from, anchor, to, xOffset, yOffset)
	local bar = setmetatable(CreateFrame("Frame", "AdiCastBar_"..unit, UIParent), barMeta)

	bar.unit, bar.realUnit = unit, unit

	local withLatency = false
	if unit == "player" then
		withLatency = true
		bar.latency = {}
		bar.latencyStart = {}
		DisableBlizzardFrame(CastingBarFrame)
	elseif unit == "target" then
		DisableBlizzardFrame(TargetFrameSpellBar)
	elseif unit == "focus" then
		DisableBlizzardFrame(FocusFrameSpellBar)
	elseif unit == "pet" then
		DisableBlizzardFrame(PetCastingBarFrame)
	end

	return bar:Initialize(unit, width, height, unit.." casting bar", from, anchor, to, xOffset, yOffset, withLatency)
end
