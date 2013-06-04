--[[
AdiCastBar - customized unit cast bars
(c) 2009-2013 Adirelle (adirelle@gmail.com)
All rights reserved.
--]]

local _, addon = ...

local _G = _G
local GetSpellCooldown = _G.GetSpellCooldown
local GetSpellInfo = _G.GetSpellInfo
local GetTime = _G.GetTime
local IsLoggedIn = _G.IsLoggedIn
local print = _G.print
local UnitClass = _G.UnitClass

local _, class = UnitClass('player')
local spellId
if class == 'DEATHKNIGHT' then
	spellId = 45902 -- Blood Strike
elseif class == 'DRUID' then
	spellId = 50464 -- Healing Touch
elseif class == 'HUNTER' then
	spellId = 1978 -- Serpent Sting
elseif class == 'MAGE' then
	spellId = 133 -- Fireball
elseif class == 'PALADIN' then
	spellId = 19750 -- Flash of Light
elseif class == 'PRIEST' then
	spellId = 2061 -- Flash Heal
elseif class == 'ROGUE' then
	spellId = 1752 -- Sinister Strike
elseif class == 'SHAMAN' then
	spellId = 331 -- Healing Wave
elseif class == 'WARLOCK' then
	spellId = 348 -- Immolate
elseif class == 'WARRIOR' then
	spellId = 6673 -- Battle Shout
elseif class == 'MONK' then
	spellId = 100787 -- Tiger Palm
end

if not spellId then
	print('AdiCastBar: no spell to test GCD for', class)
	function addon.EnableCastBar() end
	return
end

local spellName = GetSpellInfo(spellId)

local GetTime = GetTime
local GetSpellCooldown = GetSpellCooldown

local function UpdateTimer(self)
	local now = GetTime()
	if now >= self.endTime then
		self:Hide()
	end
	self.Spark:SetPoint("CENTER", self, "LEFT", (now - self.startTime) * self:GetWidth() / self.duration, 0)
end

local function Update(self, event)
	local start, duration, enable = GetSpellCooldown(spellName)
	if enable == 1 and start and duration > 0 and duration <= 1.5 then
		self.startTime = start
		self.duration = duration
		self.endTime = start + duration

		self:Show()
	elseif duration == 0 then
		self:Hide()
	end
end

local function OnEnable(self)
	self:RegisterEvent('PLAYER_ENTERING_WORLD', Update)
	self:RegisterEvent('SPELL_UPDATE_COOLDOWN', Update)
	self:SetScript('OnUpdate', UpdateTimer)
	self:Hide()
	if IsLoggedIn() then
		Update(self, "OnEnable")
	end
end

local function OnDisable(self)
	self:UnregisterEvent('PLAYER_ENTERING_WORLD', Update)
	self:UnregisterEvent('SPELL_UPDATE_COOLDOWN', Update)
	self:SetScript('OnUpdate', nil)
	self:Hide()
end

local AdiEvent = LibStub('LibAdiEvent-1.0')
function addon.InitGCD(self)
	AdiEvent.Embed(self)
	self.OnEnable = OnEnable
	self.OnDisable = OnDisable
	self:Hide()
end
