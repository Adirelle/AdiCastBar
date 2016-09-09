--[[
AdiCast Bar - customized unit cast bars
(c) 2009-2014 Adirelle (adirelle@gmail.com)
All rights reserved.
--]]

local addonName, addon = ...

local _G = _G
local CreateFrame = _G.CreateFrame
local pairs = _G.pairs
local SlashCmdList = _G.SlashCmdList
local UIParent = _G.UIParent

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

local DEFAULT_LSM_FONT = "ABF"
local DEFAULT_LSM_STATUSBAR = "BantoBar"

local RegisterFont, RegisterTexture
do
	local function UpdateFont(fs)
		fs:SetFont(FONT_PATH, FONT_SIZE, FONT_FLAGS)
		fs:SetShadowColor(0,0,0,0.5)
		fs:SetShadowOffset(1, -1)
	end

	local function UpdateTexture(tex)
		return (tex.SetStatusBarTexture or tex.SetTexture)(tex, BAR_TEXTURE)
	end

	local lsm = LibStub('LibSharedMedia-3.0', true)
	if lsm then
		BAR_TEXTURE = lsm:Fetch("statusbar", DEFAULT_LSM_STATUSBAR, true) or BAR_TEXTURE
		FONT_PATH = lsm:Fetch("statusbar", DEFAULT_LSM_FONT, true) or FONT_PATH

		local function LibSharedMedia_SetGlobal(widget, event, media, value)
			if media == "statusbar" then
				BAR_TEXTURE = lsm:Fetch(media, value)
				UpdateTexture(widget)
			end
			if media == "font" then
				FONT_PATH = lsm:Fetch(media, value)
				UpdateFont(widget)
			end
		end

		function RegisterTexture(tex)
			UpdateTexture(tex)
			lsm.RegisterCallback(tex, 'LibSharedMedia_SetGlobal', LibSharedMedia_SetGlobal)
		end

		function RegisterFont(fs)
			UpdateFont(fs)
			lsm.RegisterCallback(fs, 'LibSharedMedia_SetGlobal', LibSharedMedia_SetGlobal)
		end
	else
		RegisterTexture = UpdateTexture
		RegisterFont = UpdateFont
	end
end

local function OnBarValuesChange(bar)
	if not bar:IsShown() then return end
	local current, width, min, max = bar:GetValue(), bar:GetWidth(), bar:GetMinMaxValues()
	local delay = bar:GetParent().delay
	if delay then
		bar.TimeText:SetFormattedText("|cffff0000%+.2f|r %.2f/%.2f", delay, current-min, max-min)
	else
		bar.TimeText:SetFormattedText("%.2f / %.2f", current-min, max-min)
	end
	bar.Spark:SetPoint("CENTER", bar, "LEFT", width * (current-min) / (max-min), 0)
end

function addon.castBarProto:InitializeWidget(width, height, withLatency)
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
end

function addon.gcdProto:InitializeWidget(width, height)
	self:SetBackdrop(BAR_BACKDROP)
	self:SetBackdropColor(0,0,0,1)

	local spark = self:CreateTexture(nil, "OVERLAY")
	spark:SetTexture([[Interface\CastingBar\UI-CastingBar-Spark]])
	spark:SetBlendMode('ADD')
	spark:SetWidth(20)
	spark:SetHeight(height*2.2)
	self.Spark = spark
end

function addon:SpawnAllBars()
	local player = self:SpawnCastBar('player', 250, 20, "BOTTOM", UIParent, "BOTTOM", 0, 180)
	self:SpawnGCDBar(250, 4, "TOP", player, "BOTTOM", 0, -4)
	self:SpawnCastBar('pet', 200, 15, "BOTTOM", player, "TOP", 0, 10)

	local target = self:SpawnCastBar('target', 330, 32, "TOP", UIParent, "TOP", 0, -220)
	self:SpawnCastBar('focus', 250, 20, "TOP", target, "BOTTOM", 0, -10)
end
