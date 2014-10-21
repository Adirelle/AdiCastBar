--[[
AdiCastBar - customized unit cast bars
(c) 2009-2014 Adirelle (adirelle@gmail.com)
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
	spellId = 50842 -- Blood Boil
elseif class == 'DRUID' then
	spellId = 5176 -- Wrath
elseif class == 'HUNTER' then
	spellId = 3044 -- Arcane Shot
elseif class == 'MAGE' then
	spellId = 44614 -- Frostfire Bolt
elseif class == 'PALADIN' then
	spellId = 35395 -- Crusader Strike
elseif class == 'PRIEST' then
	spellId = 585 -- Smite
elseif class == 'ROGUE' then
	spellId = 1752 -- Sinister Strike
elseif class == 'SHAMAN' then
	spellId = 403 -- Lightning Bolt
elseif class == 'WARLOCK' then
	spellId = 686 -- Shadow Bolt
elseif class == 'WARRIOR' then
	spellId = 6673 -- Battle Shout
elseif class == 'MONK' then
	spellId = 100780 -- Jab
end

local spellName = GetSpellInfo(spellId)

local GetTime = GetTime
local GetSpellCooldown = GetSpellCooldown

local gcdProto = setmetatable({}, addon.abstractMeta)
local gcdMeta = { __index = gcdProto }
addon.gcdProto = gcdProto

function gcdProto:UpdateTimer()
	local now = GetTime()
	if now >= self.endTime then
		self:Hide()
	end
	self.Spark:SetPoint("CENTER", self, "LEFT", (now - self.startTime) * self:GetWidth() / self.duration, 0)
end

function gcdProto:SPELL_UPDATE_COOLDOWN(event)
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

gcdProto.PLAYER_ENTERING_WORLD = gcdProto.SPELL_UPDATE_COOLDOWN

function gcdProto:OnEnable()
	if not spellId then return end
	self:RegisterEvent('PLAYER_ENTERING_WORLD')
	self:RegisterEvent('SPELL_UPDATE_COOLDOWN')
	self:Hide()
	if IsLoggedIn() then
		self:SPELL_UPDATE_COOLDOWN("OnEnable")
	end
end

function gcdProto:OnDisable()
	self:UnregisterAllEvents()
	self:Hide()
end

function addon:SpawnGCDBar(width, height, from, anchor, to, xOffset, yOffset)
	local bar = setmetatable(CreateFrame("Frame", "AdiCastBar_GCD", UIParent), gcdMeta)
	bar:SetScript('OnUpdate', bar.UpdateTimer)
	return bar:Initialize("gcd", width, height, "Global cooldown", from, anchor, to, xOffset, yOffset)
end
