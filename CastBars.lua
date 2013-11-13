--[[
AdiCastBar - customized unit cast bars
(c) 2009-2013 Adirelle (adirelle@gmail.com)
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

local GetTime = GetTime

local barProto = setmetatable({ Debug = addon.Debug }, addon.frameMeta)
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

function barProto:TimerUpdate()
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

function barProto:SetNotInterruptible(notInterruptible)
	if notInterruptible then
		self.Border:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
		self.Shield:Show()
	else
		self.Border:SetBackdropBorderColor(0, 0, 0, 1)
		self.Shield:Hide()
	end
end

function barProto:SetTime(startTime, endTime, delayed)
	if not delayed then
		self.startTime = startTime
		self.delay = nil
	else
		self.delay = startTime - self.startTime
	end
	self.endTime = endTime
	self.Bar:SetMinMaxValues(0, endTime-startTime)
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

	if self.Ticks and self.SpellTicks then
		self:HideTicks()
		local num = self.SpellTicks[name]
		if type(num) == "function" then
			num = num()
		end
		if reversed and num then
			local offset = self.Bar:GetWidth() / num
			for i = 1, num do
				local tick = self:GetTick(i)
				tick:SetPoint("BOTTOM", self.Bar, "TOPLEFT", offset * (i-1), -3)
				tick:Show()
			end
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
	self:SetScript('OnUpdate', TimerUpdate)
	self:Show()
end

function barProto:UNIT_SPELLCAST_START(event, unit, _, _, castId)
	local name, rank, text, texture, startTime, endTime, _, castId, notInterruptible = UnitCastingInfo(unit)
	self:Debug(event, unit, castId, rank, name, text, texture, startTime, endTime, castId, notInterruptible)
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

function barProto:UNIT_SPELLCAST_CHANNEL_START(event, unit)
	local name, _, text, texture, startTime, endTime, _, notInterruptible = UnitChannelInfo(unit)
	self:Debug(event, unit, name, text, texture, startTime, endTime, notInterruptible)
	return self:StartCast(true, COLORS.CHANNEL, name, text, texture, startTime/1000, endTime/1000, notInterruptible, "CHANNEL")
end

function barProto:UNIT_SPELLCAST_CHANNEL_UPDATE(event, unit)
	if self.castId ~= "CHANNEL" then return end
	local _, _, _, _, startTime, endTime = UnitChannelInfo(unit)
	self:Debug(event, unit, startTime, endTime)
	return SetTime(self, startTime/1000, endTime/1000, true)
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

function barProto:SPELLS_CHANGED(event)
	local data = {
		-- Warlock
		[689] = 3, -- Drain Life
		[5740] = 4, -- Rain of Fire
		-- [85403] = 15, -- Hellfire
		[103103] = 4, -- Malefic Grasp
		-- Druid
		[16914] = 10, -- Hurricane
		[740] = 4, -- Tranquility
		[106996] = 10, -- Astral Storm
		[127663] = 4, -- Astral Communion
		-- Priest
		[15407] = 3, -- Mind Flay
		[48045] = 5, -- Mind Sear
		[47540] = 3, -- Penance
		-- Mage
		[5143] = 5, -- Arcane Missile
		[10] = 8, -- Blizzard
	}
	self.SpellTicks = {}
	for id, num in pairs(data) do
		local name = GetSpellInfo(id)
		if name then
			self.SpellTicks[name] = num
		end
	end
end

function barProto:UNIT_AURA()
	-- NOOP
end

local DRData, minor = LibStub('DRData-1.0', true)
if DRData then
	local UnitDebuff = UnitDebuff
	local INTERESTING_CATEGORY = {
		banish = true,
		charge = true,
		cheapshot = true,
		ctrlstun = true,
		cyclone = true,
		disorient = true,
		fear = true,
		horror = true,
		mc = true,
		rndstun = true,
		scatters = true,
		silence = true,
		sleep = true,
	}
	for name, color in pairs(DebuffTypeColor) do
		COLORS[name] = { color.r, color.g, color.b }
	end

	addon.Debug('PvP Debuff support using DRData-1.0', minor)

	local function SearchDebuff(unit)
		local name, texture, dType, duration, endTime, spellId
		for i = 1, 4000 do
			local iName, _, iTexture, _, iDType, iDuration, iEndTime, _, _, _, iSpellId = UnitDebuff(unit, i)
			if iName then
				local category = DRData:GetSpellCategory(iSpellId)
				if category and INTERESTING_CATEGORY[category] and (iDuration or 0) > 0 and iEndTime and (not name or iEndTime > endTime) then
					name, texture, dType, duration, endTime, spellId = iName, iTexture, iDType, iDuration, iEndTime, iSpellId
				end
			else
				break
			end
		end
		if name then
			addon.Debug('Found debuff:', name, 'on:', unit)
			return name, texture, dType, duration, endTime, spellId
		end
	end

	function barProto:UNIT_AURA(event, unit)
		local currentId = tonumber(tostring(self.castId):match('^AURA(%d+)$'))
		if not UnitIsPVP("player") then
			return not currentId or FadeOut(self)
		end
		local name, texture, dType, duration, endTime, spellId = SearchDebuff(unit)
		if spellId then
			if spellId ~= currentId then
				self:Debug('Showing debuff:', name, 'on:', unit)
				self:StartCast(true, COLORS[dType or "none"], name, nil, texture, endTime-duration, endTime, false, 'AURA'..spellId)
			end
		elseif currentId then
			self:Debug('Hiding debuff:', GetSpellInfo(currentId), 'on:', unit)
			self:FadeOut()
		end
	end
end

function barProto:PLAYER_ENTERING_WORLD(event)
	local unit = self.unit
	self:Debug(event, unit, "casting:", UnitCastingInfo(unit), "channeling:", (UnitChannelInfo(unit)))
	if UnitCastingInfo(unit) then
		return self:UNIT_SPELLCAST_START(event, unit)
	elseif UnitChannelInfo(unit) then
		return self:UNIT_SPELLCAST_CHANNEL_START(event, unit)
	elseif self:IsShown() then
		self.castId = nil
		self:Hide()
	end
	self:UNIT_AURA(event, unit)
end

function barProto:UNIT_PET(event, unit)
	return self:PLAYER_ENTERING_WORLD(self, event)
end

function barProto:LatencyStart(event, unit, spell)
	if unit and unit ~= self.unit then return end
	self.latency[spell] = nil
	self.latencyStart[spell] = GetTime()
end

function barProto:LatencyEnd(event, unit, spell)
	if unit and unit ~= self.unit then return end
	local start = self.latencyStart[spell]
	if start then
		self.latency[spell] = GetTime() - start
		self.latencyStart[spell] = nil
	end
end

function barProto:UpdateVehicleState(event, unit)
	if unit and unit ~= 'player' then return end
	local newUnit = UnitHasVehicleUI('player') and 'vehicle' or 'player'
	if newUnit ~= self.unit then
		self:Debug("UpdateVehicleState", unit, "self.unit=", self.unit, "newUnit=", newUnit)
		self.unit = newUnit
		return self:PLAYER_ENTERING_WORLD(self)
	end
end

local function noop() end
local function DisableBlizzardFrame(frame)
	frame.RegisterEvent = noop
	frame.Show = noop
	frame:UnregisterAllEvents()
	frame:Hide()
end

function barProto:OnEnable()
	local unit = self.realUnit

	if self.Latency then
		self:RegisterUnitEvent("UNIT_SPELLCAST_SENT", LatencyStart)
		self:RegisterUnitEvent("UNIT_SPELLCAST_START", LatencyEnd)
		self:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", LatencyEnd)
	end

	self:RegisterEvent("PLAYER_ENTERING_WORLD")

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

	if unit == "target" then
		self.PLAYER_TARGET_CHANGED = self.PLAYER_ENTERING_WORLD
		self:RegisterEvent("PLAYER_TARGET_CHANGED")

	elseif unit == "focus" then
		self.PLAYER_FOCUS_CHANGED = self.PLAYER_ENTERING_WORLD
		self:RegisterEvent("PLAYER_FOCUS_CHANGED")

	elseif unit == "pet" then
		self:RegisterUnitEvent("UNIT_PET", "pet")
	end

	if unit == "player" then
		self:RegisterEvent("SPELLS_CHANGED", SPELLS_CHANGED)

		self:RegisterEvent("PLAYER_ENTERING_WORLD", UpdateVehicleState)
		self:RegisterEvent("UNIT_ENTERED_VEHICLE", UpdateVehicleState)
		self:RegisterEvent("UNIT_EXITED_VEHICLE", UpdateVehicleState)
		UpdateVehicleState(self, "OnEnable")

	end

	self:RegisterUnitEvent("UNIT_AURA", unit)

	if IsLoggedIn() then
		self:PLAYER_ENTERING_WORLD('OnEnable')
		if unit == "player" then
			self:SPELLS_CHANGED("OnEnable")
		end
	end
end

function barProto:OnDisable()
	self:UnregisterAllEvents()
	self:Hide()
end

function barProto:Initialize(unit)
	if self.Latency then
		self.latency = {}
		self.latencyStart = {}
	end

	local unit = self.unit
	if unit == "player" then
		DisableBlizzardFrame(CastingBarFrame)
	elseif unit == "target" then
		DisableBlizzardFrame(TargetFrameSpellBar)
	elseif unit == "focus" then
		DisableBlizzardFrame(FocusFrameSpellBar)
	elseif unit == "pet" then
		DisableBlizzardFrame(PetCastingBarFrame)
	end
end

function addon.SpawnCastBar(unit, width, height, withLatency)
	local bar = setmetatable(CreateFrame("Frame", "AdiCastBar_"..unit, UIParent), barMeta)
	bar:SetScript('OnEvent', addon.OnEvent)
	bar.unit, bar.realUnit = unit, unit
	bar:InitializeWidget(width, height, withLatency)
	bar:Initialize()
	return bar
end
