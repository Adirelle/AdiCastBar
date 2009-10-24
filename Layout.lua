--[[
AdiCastBar - customized unit cast bars
(c) 2009 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

if not AdiCastBar then return end
setfenv(1, AdiCastBar)

local BAR_BACKDROP = {
	bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
	 tile = true,
	 tileSize = 16,
}

local BORDER_SIZE = 2
local BORDER_BACKDROP = {
	edgeFile = [[Interface\Addons\oUF_Adirelle\media\white16x16]], 
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
			
	local lsm = LibStub('LibSharedMedia-3.0', false)
	if lsm then
		local altFont = lsm:Fetch("font", LSM_FONT, true)
		if altFont then
			FONT_PATH, FONT_SIZE, FONT_FLAGS = altFont, 12, ""
		end
	
		BAR_TEXTURE = lsm:Fetch("statusbar", LSM_STATUSBAR, true) or BAR_TEXTURE
		
		local function LibSharedMedia_SetGlobal(tex, media, value)
			if media == "statusbar" then
				BAR_TEXTURE = lsm:Fetch("statusbar", value)
				UpdateTexture(tex)
			end			
		end

		function RegisterTexture(tex)
			UpdateTexture(tex)
			tex.LibSharedMedia_SetGlobal = LibSharedMedia_SetGlobal
			lsm.RegisterCallback(tex, 'LibSharedMedia_SetGlobal')
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
	icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
	self.Icon = icon
		
	local bar = CreateFrame("StatusBar", nil, self)
	RegisterTexture(bar)
	bar:SetPoint("TOPLEFT", icon , "TOPRIGHT", 2, 0)
	bar:SetPoint("BOTTOMRIGHT", self)
	bar:SetScript('OnMinMaxChanged', OnBarValuesChange)
	bar:SetScript('OnValueChanged', OnBarValuesChange)
	bar:SetScript('OnShow', OnBarValuesChange)
	self.Bar = bar
	
	if withLatency then
		local latency = bar:CreateTexture(nil, "ARTWORK")
		latency:SetTexture(0.5, 0, 0, 0.5)
		latency:SetBlendMode("BLEND")
		latency:SetHeight(height)
		self.Latency = latency
	end
	
	local timeText = bar:CreateFontString(nil, "OVERLAY")
	RegisterFont(timeText)
	timeText:SetPoint("TOPLEFT", bar, 2, 0)
	timeText:SetPoint("BOTTOMRIGHT", bar, -2, 0)
	timeText:SetJustifyH("RIGHT")
	timeText:SetJustifyV("MIDDLE")
	bar.TimeText = timeText

	local text = bar:CreateFontString(nil, "OVERLAY")
	RegisterFont(text)
	text:SetPoint("TOPLEFT", bar, 2, 0)
	text:SetPoint("BOTTOMRIGHT", bar, -2, 0)
	text:SetJustifyH("LEFT")
	text:SetJustifyV("MIDDLE")
	self.Text = text

	local spark = bar:CreateTexture(nil, "OVERLAY")
	spark:SetTexture([[Interface\CastingBar\UI-CastingBar-Spark]])
	spark:SetBlendMode('ADD')
	spark:SetWidth(20)
	spark:SetHeight(height*2.2)	
	bar.Spark = spark
	
	EnableCastBar(self)
	self:Hide()
	return self
end

local player = SpawnCastBar('player', 250, 20, true)
player:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 180)

local target = SpawnCastBar('target', 330, 32)
target:SetPoint("TOP", UIParent, "TOP", 0, -220)

