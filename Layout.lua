--[[
AdiCastBar - customized unit cast bars
(c) 2009 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, AdiCastBar = ...
setfenv(1, AdiCastBar)

local BAR_BACKDROP = {
	bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
	tile = true,
	tileSize = 16,
}

local BORDER_SIZE = 2
local BORDER_BACKDROP = {
	edgeFile = [[Interface\Addons\AdiCastBar\media\white16x16]],
	edgeSize = BORDER_SIZE,
}

local BAR_TEXTURE = [[Interface\TargetingFrame\UI-StatusBar]]
local FONT_PATH, FONT_SIZE, FONT_FLAGS = GameFontWhite:GetFont()

local LSM_FONT = "ABF"
local LSM_STATUSBAR = "BantoBar"

do
	function RegisterFont(fs)
		fs:SetFont(FONT_PATH, FONT_SIZE, FONT_FLAGS)
		fs:SetShadowColor(0,0,0,0.5)
		fs:SetShadowOffset(1, -1)
	end

	local function UpdateTexture(tex)
		return (tex.SetStatusBarTexture or tex.SetTexture)(tex, BAR_TEXTURE)
	end

	local lsm = LibStub('LibSharedMedia-3.0', true)
	if lsm then
		BAR_TEXTURE = lsm:Fetch("statusbar", LSM_STATUSBAR, true) or BAR_TEXTURE

		local function LibSharedMedia_SetGlobal(tex, event, media, value)
			if media == "statusbar" then
				BAR_TEXTURE = lsm:Fetch("statusbar", value)
				UpdateTexture(tex)
			end
		end

		function RegisterTexture(tex)
			UpdateTexture(tex)
			lsm.RegisterCallback(tex, 'LibSharedMedia_SetGlobal', LibSharedMedia_SetGlobal)
		end
	else
		RegisterTexture = UpdateTexture
	end
end

local function OnBarValuesChange(bar)
	if not bar:IsShown() then return end
	local current, width, min, max = bar:GetValue(), bar:GetWidth(), bar:GetMinMaxValues()
	local delay = bar:GetParent().delay
	if delay then
		bar.TimeText:SetFormattedText("|cffff0000%+.1f|r %.1f/%.1f", delay, current-min, max-min)
	else
		bar.TimeText:SetFormattedText("%.1f / %.1f", current-min, max-min)
	end
	bar.Spark:SetPoint("CENTER", bar, "LEFT", width * (current-min) / (max-min), 0)
end

local function GetTick(self, index)
	local tick = self.Ticks[index]
	if not tick then
		tick = self.Bar:CreateTexture(nil, "OVERLAY")
		tick:SetSize(7, 8)
		tick:SetTexture([[Interface\BUTTONS\UI-SortArrow]])
		tick:SetTexCoord(2/16, 8/16, 0, 1)
		self.Ticks[index] = tick
	end
	return tick
end

local function HideTicks(self)
	for i, tick in pairs(self.Ticks) do
		tick:Hide()
	end
end

local function SpawnCastBar(unit, width, height, withLatency)
	local self = CreateFrame("Frame", "AdiCastBar_"..unit, UIParent)
	self.unit = unit
	self:SetWidth(width)
	self:SetHeight(height)
	self:SetBackdrop(BAR_BACKDROP)
	self:SetBackdropColor(0, 0, 0, 1)
	self:SetBackdropBorderColor(0, 0, 0, 0)

	local border = CreateFrame("Frame", nil, self)
	border:SetWidth(width+BORDER_SIZE*2)
	border:SetHeight(height+BORDER_SIZE*2)
	border:SetPoint("CENTER")
	border:SetBackdrop(BORDER_BACKDROP)
	border:SetBackdropColor(0, 0, 0, 0)
	border:SetBackdropBorderColor(0, 0, 0, 1)
	self.Border = border

	local icon = self:CreateTexture(nil, "ARTWORK")
	icon:SetWidth(height)
	icon:SetHeight(height)
	icon:SetPoint("TOPLEFT")
	icon:SetTexCoord(5/64, 59/64, 5/64, 59/64)
	self.Icon = icon

	local shield = border:CreateTexture(nil, "OVERLAY")
	local shieldSize = height*64/18
	shield:SetWidth(shieldSize)
	shield:SetHeight(shieldSize)
	shield:SetPoint("TOPLEFT", icon, "TOPLEFT", -11/64*shieldSize, 22/64*shieldSize)
	shield:SetTexture([[Interface\CastingBar\UI-CastingBar-Arena-Shield]])
	self.Shield = shield
	
	local bar = CreateFrame("StatusBar", nil, self)
	RegisterTexture(bar)
	bar:SetPoint("TOPLEFT", icon, "TOPRIGHT", 2, 0)
	bar:SetPoint("BOTTOMRIGHT", self)
	bar:SetScript('OnMinMaxChanged', OnBarValuesChange)
	bar:SetScript('OnValueChanged', OnBarValuesChange)
	bar:SetScript('OnShow', OnBarValuesChange)
	bar:SetFrameLevel(border:GetFrameLevel()+1)
	self.Bar = bar

	if withLatency then
		local latency = bar:CreateTexture(nil, "OVERLAY")
		latency:SetTexture(0.5, 0, 0, 0.5)
		latency:SetBlendMode("BLEND")
		latency:SetHeight(height)
		self.Latency = latency
	end

	if unit == "player" then
		self.Ticks = {}
		self.GetTick = GetTick
		self.HideTicks = HideTicks
	end

	local timeText = bar:CreateFontString(nil, "OVERLAY")
	RegisterFont(timeText)
	timeText:SetPoint("TOPRIGHT", bar, -2, 0)
	timeText:SetPoint("BOTTOMRIGHT", bar, -2, 0)
	timeText:SetJustifyH("RIGHT")
	timeText:SetJustifyV("MIDDLE")
	bar.TimeText = timeText

	local text = bar:CreateFontString(nil, "OVERLAY")
	RegisterFont(text)
	text:SetPoint("TOPLEFT", bar, 2, 0)
	text:SetPoint("BOTTOMLEFT", bar, 2, 0)
	text:SetPoint("RIGHT", timeText, "LEFT", -2, 0)
	text:SetJustifyH("LEFT")
	text:SetJustifyV("MIDDLE")
	self.Text = text

	local spark = bar:CreateTexture(nil, "OVERLAY")
	spark:SetTexture([[Interface\CastingBar\UI-CastingBar-Spark]])
	spark:SetBlendMode('ADD')
	spark:SetWidth(20)
	spark:SetHeight(height*2.2)
	bar.Spark = spark

	InitCastBar(self)
	return self
end

local function SpawnGCDBar(_, width, height)
	local self = CreateFrame("Frame", "AdiCastBar_GCD", UIParent)
	self:SetWidth(width)
	self:SetHeight(height)

	self:SetBackdrop(BAR_BACKDROP)
	self:SetBackdropColor(0,0,0,1)

	local spark = self:CreateTexture(nil, "OVERLAY")
	spark:SetTexture([[Interface\CastingBar\UI-CastingBar-Spark]])
	spark:SetBlendMode('ADD')
	spark:SetWidth(20)
	spark:SetHeight(height*2.2)
	self.Spark = spark

	InitGCD(self)
	return self
end

local AdiEvent = LibStub('LibAdiEvent-1.0')

local function AddonLoaded(self, _, name)
	if name ~= addonName then return end
	AdiEvent:UnregisterEvent('ADDON_LOADED', AddonLoaded)

	_G.AdiCastBarDB = _G.AdiCastBarDB or {}
	local db = _G.AdiCastBarDB
	db.disabled = db.disabled or {}

	local Movable = LibStub('LibMovable-1.0')
	local function Spawn(spawnFunc, key, label, width, height, from, anchor, to, xOffset, yOffset, ...)
		Debug('Spawn', 'key=', key, 'label=', label, 'point=', from, anchor, to, xOffset, yOffset, 'spawnArgs=', key, width, height, ...)
		local bar = spawnFunc(key, width, height, ...)
		bar:SetPoint(from, anchor, to, xOffset, yOffset)
		bar.LM10_Enable = function(self) db.disabled[key] = nil self:OnEnable() end
		bar.LM10_Disable = function(self) db.disabled[key] = true self:OnDisable() end
		bar.LM10_IsEnabled = function() return not db.disabled[key] end
		db[key] = db[key] or {}
		Movable.RegisterMovable(addonName, bar, db[key], label)
		if not db.disabled[key] then
			bar:OnEnable()
		end
		return bar
	end

	local player = Spawn(
		SpawnCastBar, 'player', "Player casting bar", 250, 20,
		"BOTTOM", UIParent, "BOTTOM", 0, 180,
		true
	)
	Spawn(
		SpawnGCDBar, 'gcd', "Player global cooldown", 250, 4,
		"TOP", player, "BOTTOM", 0, -4
	)
	Spawn(
		SpawnCastBar, 'pet', "Pet casting bar", 200, 15,
		"BOTTOM", player, "TOP", 0, 10
	)
	local target = Spawn(
		SpawnCastBar, 'target', "Target casting bar", 330, 32,
		"TOP", UIParent, "TOP", 0, -220
	)
	Spawn(
		SpawnCastBar, "focus", "Focus casting bar", 250, 20,
		"TOP", target, "BOTTOM", 0, -10
	)

	_G.SLASH_ADICASTBAR1 = "/adicastbar"
	_G.SLASH_ADICASTBAR2 = "/acb"
	SlashCmdList.ADICASTBAR = function()
		if Movable.IsLocked(addonName) then
			Movable.Unlock(addonName)
		else
			Movable.Lock(addonName)
		end
	end
end

AdiEvent:RegisterEvent('ADDON_LOADED', AddonLoaded)
