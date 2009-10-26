--[[
AdiCastBar - customized unit cast bars
(c) 2009 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

if not AdiCastBar then return end
setfenv(1, AdiCastBar)

local _, class = UnitClass('player')
local spellId
if class == 'DEATHKNIGHT' then
	spellId = 4590 -- Blood Strike
elseif class == 'DRUID' then
	spellId = 5185 -- Healing Touch
elseif class == 'HUNTER' then
	spellId = 1978 -- Serpent Sting
elseif class == 'MAGE' then
	spellId = 133 -- Fireball
elseif class == 'PALADIN' then
	spellId = 66922 -- Flash of Light
elseif class == 'PRIEST' then
	spellId = 2050 -- Lesser Heal
elseif class == 'ROGUE' then
	spellId = 1752 -- Sinister Strike
elseif class == 'SHAMAN' then
	spellId = 331 -- Healing Wave
elseif class == 'WARLOCK' then
	spellId = 348 -- Immolate
elseif class == 'WARRIOR' then
	spellId = 6673 -- Battle Shout
end

if not spellId then
	print('AdiCastBar: no spell to test GCD for', class)
	function EnableCastBar() end
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
	self.Spark:SetPoint("LEFT", self, "LEFT", (now - self.startTime) * self:GetWidth() / self.duration, 0)
end

local function Update(self, event)
	local start, duration, enable = GetSpellCooldown(spellName)
	if enable == 1 and duration > 0 and duration <= 1.5 then
		print(event, duration)
		self.startTime = start
		self.duration = duration
		self.endTime = start + duration
		
		self:Show()
	elseif duration == 0 then
		self:Hide()
	end
end

local lae = LibStub('LibAdiEvent-1.0')
function EnableGCD(self)
	lae.Embed(self)
	
	self:RegisterEvent('PLAYER_ENTERING_WORLD', Update)
	self:RegisterEvent('SPELL_UPDATE_COOLDOWN', Update)
	self:SetScript('OnUpdate', UpdateTimer)
	
	Update(self, "EnableGCD")
end
