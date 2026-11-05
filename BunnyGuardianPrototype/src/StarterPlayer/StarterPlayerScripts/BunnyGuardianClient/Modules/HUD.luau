-- HUD: wave counter, burrow health, boss bar, mana, coins, ability buttons,
-- upgrade buttons and notification banner. Built entirely in code.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local BunnyGuardian = ReplicatedStorage:WaitForChild("BunnyGuardian")
local Config = require(BunnyGuardian:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = BunnyGuardian:WaitForChild("Remotes")
local GameState = BunnyGuardian:WaitForChild("GameState")
local BuyUpgradeRemote = Remotes:WaitForChild("BuyUpgrade") :: RemoteFunction
local NotifyRemote = Remotes:WaitForChild("Notify") :: RemoteEvent

local player = Players.LocalPlayer

local HUD = {}

local FONT = Enum.Font.FredokaOne
local COLORS = {
	Panel = Color3.fromRGB(255, 248, 240),
	PanelStroke = Color3.fromRGB(120, 80, 60),
	Text = Color3.fromRGB(70, 45, 35),
	BarBack = Color3.fromRGB(60, 40, 35),
	Health = Color3.fromRGB(120, 210, 90),
	HealthLow = Color3.fromRGB(230, 70, 60),
	Mana = Color3.fromRGB(80, 160, 255),
	Boss = Color3.fromRGB(190, 60, 200),
	Coin = Color3.fromRGB(255, 200, 40),
	Kick = Color3.fromRGB(90, 220, 120),
	Carrot = Color3.fromRGB(245, 140, 40),
	Cyclone = Color3.fromRGB(150, 220, 230),
	Upgrade = Color3.fromRGB(255, 225, 160),
}

------------------------------------------------------------------------
-- Tiny UI helpers
------------------------------------------------------------------------

local function create(className: string, props: { [string]: any }, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent = props.Parent
	for key, value in props do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	instance.Parent = parent
	return instance
end

local function corner(radius: number): UICorner
	return create("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function stroke(color: Color3, thickness: number): UIStroke
	return create("UIStroke", { Color = color, Thickness = thickness, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function label(props: { [string]: any }): TextLabel
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or FONT
	props.TextColor3 = props.TextColor3 or COLORS.Text
	props.TextScaled = if props.TextScaled == nil then true else props.TextScaled
	return create("TextLabel", props)
end

type Bar = { Frame: Frame, Fill: Frame, Text: TextLabel }

local function makeBar(parent: Instance, position: UDim2, size: UDim2, color: Color3): Bar
	local frame = create("Frame", {
		Position = position,
		Size = size,
		BackgroundColor3 = COLORS.BarBack,
		BorderSizePixel = 0,
		Parent = parent,
	}, { corner(8), stroke(COLORS.PanelStroke, 2) })
	local fill = create("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = frame,
	}, { corner(8) })
	local text = label({
		Size = UDim2.new(1, -8, 1, -4),
		Position = UDim2.fromOffset(4, 2),
		TextColor3 = Color3.new(1, 1, 1),
		ZIndex = 2,
		Parent = frame,
	})
	create("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1.5, Transparency = 0.3, Parent = text })
	return { Frame = frame, Fill = fill, Text = text }
end

local function setBar(bar: Bar, value: number, maxValue: number, text: string)
	local ratio = if maxValue > 0 then math.clamp(value / maxValue, 0, 1) else 0
	bar.Fill.Size = UDim2.fromScale(ratio, 1)
	bar.Fill.Visible = ratio > 0
	bar.Text.Text = text
end

------------------------------------------------------------------------
-- Build
------------------------------------------------------------------------

local screen: ScreenGui
local waveLabel: TextLabel
local statusLabel: TextLabel
local burrowBar: Bar
local bossBar: Bar
local bossFrame: Frame
local manaBar: Bar
local coinsLabel: TextLabel
local banner: TextLabel
local toast: TextLabel
local abilityButtons: { [string]: { Button: TextButton, Overlay: Frame, Timer: TextLabel } } = {}
local upgradeButtons: { [string]: TextButton } = {}

local function buildTop()
	local top = create("Frame", {
		Name = "TopPanel",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(380, 104),
		BackgroundColor3 = COLORS.Panel,
		BackgroundTransparency = 0.08,
		Parent = screen,
	}, { corner(14), stroke(COLORS.PanelStroke, 3) })
	label({ Text = "Bunny Guardian: Rise of the Rabbit", Size = UDim2.new(1, -16, 0, 18), Position = UDim2.fromOffset(8, 4), TextColor3 = Color3.fromRGB(200, 90, 120), Parent = top })
	waveLabel = label({ Text = "Wave 0 / 10", Size = UDim2.new(0.5, -8, 0, 28), Position = UDim2.fromOffset(8, 24), TextXAlignment = Enum.TextXAlignment.Left, Parent = top })
	statusLabel = label({ Text = "", Size = UDim2.new(0.5, -8, 0, 22), Position = UDim2.new(0.5, 0, 0, 27), TextXAlignment = Enum.TextXAlignment.Right, Parent = top })
	label({ Text = "Burrow", Size = UDim2.new(0, 70, 0, 20), Position = UDim2.fromOffset(8, 66), TextXAlignment = Enum.TextXAlignment.Left, Parent = top })
	burrowBar = makeBar(top, UDim2.fromOffset(80, 60), UDim2.new(1, -92, 0, 32), COLORS.Health)

	bossFrame = create("Frame", {
		Name = "BossPanel",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 120),
		Size = UDim2.fromOffset(460, 54),
		BackgroundColor3 = Color3.fromRGB(50, 25, 55),
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = screen,
	}, { corner(12), stroke(Color3.fromRGB(255, 200, 80), 3) })
	label({ Text = "THE GREAT EAGLE", Size = UDim2.new(1, -16, 0, 18), Position = UDim2.fromOffset(8, 3), TextColor3 = Color3.fromRGB(255, 220, 120), Parent = bossFrame })
	bossBar = makeBar(bossFrame, UDim2.fromOffset(10, 23), UDim2.new(1, -20, 0, 24), COLORS.Boss)
end

local function buildBottomLeft()
	local panel = create("Frame", {
		Name = "StatsPanel",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -12),
		Size = UDim2.fromOffset(250, 84),
		BackgroundColor3 = COLORS.Panel,
		BackgroundTransparency = 0.08,
		Parent = screen,
	}, { corner(14), stroke(COLORS.PanelStroke, 3) })
	coinsLabel = label({ Text = "Coins: 0", Size = UDim2.new(1, -16, 0, 30), Position = UDim2.fromOffset(10, 6), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(190, 130, 0), Parent = panel })
	label({ Text = "Mana", Size = UDim2.fromOffset(50, 20), Position = UDim2.fromOffset(10, 50), TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })
	manaBar = makeBar(panel, UDim2.fromOffset(62, 44), UDim2.new(1, -74, 0, 30), COLORS.Mana)
end

local function buildAbilities(onUse: (string, boolean?) -> ())
	local bar = create("Frame", {
		Name = "AbilityBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(3 * 96 + 2 * 10, 96),
		BackgroundTransparency = 1,
		Parent = screen,
	}, {
		create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center }),
	})
	local colors = { CarrotThrow = COLORS.Carrot, HurricaneKick = COLORS.Kick, EarCyclone = COLORS.Cyclone }
	for index, abilityName in Config.AbilityOrder do
		local cfg = Config.Abilities[abilityName]
		local button = create("TextButton", {
			Name = abilityName,
			LayoutOrder = index,
			Size = UDim2.fromOffset(96, 96),
			BackgroundColor3 = colors[abilityName],
			AutoButtonColor = true,
			Text = "",
			Parent = bar,
		}, { corner(16), stroke(COLORS.PanelStroke, 3) })
		label({ Text = cfg.DisplayName, Size = UDim2.new(1, -10, 0, 34), Position = UDim2.fromOffset(5, 14), TextColor3 = Color3.new(1, 1, 1), ZIndex = 2, Parent = button })
		local hint = if cfg.ManaCost > 0 then cfg.KeyHint .. "  •  " .. cfg.ManaCost .. " mana" else cfg.KeyHint
		label({ Text = hint, Size = UDim2.new(1, -10, 0, 18), Position = UDim2.new(0, 5, 1, -26), TextColor3 = Color3.fromRGB(60, 40, 30), ZIndex = 2, Parent = button })
		local overlay = create("Frame", {
			Name = "Cooldown",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.fromScale(1, 0),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.45,
			ZIndex = 3,
			Parent = button,
		}, { corner(16) })
		local timer = label({ Text = "", Size = UDim2.fromScale(1, 0.5), Position = UDim2.fromScale(0, 0.25), TextColor3 = Color3.new(1, 1, 1), ZIndex = 4, Parent = button })
		button.Activated:Connect(function()
			onUse(abilityName, false)
		end)
		abilityButtons[abilityName] = { Button = button, Overlay = overlay, Timer = timer }
	end
end

local function showToast(text: string, good: boolean)
	toast.Text = text
	toast.TextColor3 = if good then Color3.fromRGB(40, 140, 60) else Color3.fromRGB(190, 50, 50)
	toast.Visible = true
	local myText = text
	task.delay(2, function()
		if toast.Text == myText then
			toast.Visible = false
		end
	end)
end

local function refreshUpgrades()
	local coins = player:GetAttribute("Coins") or 0
	for upgradeId, button in upgradeButtons do
		local upgrade = Config.Upgrades[upgradeId]
		local level = player:GetAttribute("Upgrade_" .. upgradeId) or 0
		local cost = Config.GetUpgradeCost(upgradeId, level)
		local maxed = level >= upgrade.MaxLevel
		local title = if upgradeId == "RepairBurrow" then upgrade.DisplayName else upgrade.DisplayName .. "  Lv " .. level
		local costText = if maxed then "MAX" else cost .. " coins"
		button.Text = title .. "\n" .. upgrade.Description .. "  —  " .. costText
		local affordable = not maxed and coins >= cost
		button.BackgroundColor3 = if affordable then COLORS.Upgrade else Color3.fromRGB(215, 205, 195)
	end
end

local function buildUpgrades()
	local panel = create("Frame", {
		Name = "UpgradePanel",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(240, 40 + #Config.UpgradeOrder * 62),
		BackgroundColor3 = COLORS.Panel,
		BackgroundTransparency = 0.08,
		Parent = screen,
	}, { corner(14), stroke(COLORS.PanelStroke, 3) })
	label({ Text = "Upgrades", Size = UDim2.new(1, -16, 0, 26), Position = UDim2.fromOffset(8, 6), Parent = panel })
	local list = create("Frame", {
		Size = UDim2.new(1, -16, 1, -42),
		Position = UDim2.fromOffset(8, 36),
		BackgroundTransparency = 1,
		Parent = panel,
	}, { create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })

	for index, upgradeId in Config.UpgradeOrder do
		local button = create("TextButton", {
			Name = upgradeId,
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, 56),
			BackgroundColor3 = COLORS.Upgrade,
			Font = FONT,
			TextScaled = true,
			TextColor3 = COLORS.Text,
			Text = "",
			Parent = list,
		}, { corner(10), stroke(COLORS.PanelStroke, 2), create("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }) })
		local busy = false
		button.Activated:Connect(function()
			if busy then
				return
			end
			busy = true
			local ok, success, message = pcall(function()
				return BuyUpgradeRemote:InvokeServer(upgradeId)
			end)
			busy = false
			if ok then
				showToast(message or "", success == true)
			else
				showToast("Upgrade failed, try again", false)
			end
			refreshUpgrades()
		end)
		upgradeButtons[upgradeId] = button
	end

	toast = label({
		Name = "Toast",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 1, 6),
		Size = UDim2.new(1, 0, 0, 22),
		Visible = false,
		Parent = panel,
	})
end

local function buildBanner()
	banner = label({
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.new(0.7, 0, 0, 56),
		TextColor3 = Color3.new(1, 1, 1),
		TextTransparency = 1,
		Parent = screen,
	})
	create("UIStroke", { Name = "Outline", Color = Color3.fromRGB(60, 30, 20), Thickness = 3, Transparency = 1, Parent = banner })

	label({
		Name = "ControlsHint",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -114),
		Size = UDim2.fromOffset(520, 20),
		TextColor3 = Color3.new(1, 1, 1),
		Text = "Click / F: Carrot   •   Q: Hurricane Kick (mana)   •   E: Ear Cyclone (slows)",
		Parent = screen,
	})
end

------------------------------------------------------------------------
-- Live updates
------------------------------------------------------------------------

local BANNER_COLORS = {
	info = Color3.fromRGB(255, 255, 255),
	warning = Color3.fromRGB(255, 210, 120),
	success = Color3.fromRGB(150, 255, 150),
	boss = Color3.fromRGB(255, 120, 120),
}

local bannerToken = 0
local function showBanner(text: string, kind: string?)
	bannerToken += 1
	local myToken = bannerToken
	banner.Text = text
	banner.TextColor3 = BANNER_COLORS[kind or "info"] or BANNER_COLORS.info
	local outline = banner:FindFirstChild("Outline") :: UIStroke
	banner.TextTransparency = 0
	outline.Transparency = 0
	task.delay(2.5, function()
		if bannerToken ~= myToken then
			return
		end
		local info = TweenInfo.new(0.6)
		TweenService:Create(banner, info, { TextTransparency = 1 }):Play()
		TweenService:Create(outline, info, { Transparency = 1 }):Play()
	end)
end

local function refreshGameState()
	local wave = GameState:GetAttribute("Wave") or 0
	local total = GameState:GetAttribute("TotalWaves") or Config.Waves.Total
	waveLabel.Text = "Wave " .. wave .. " / " .. total

	local status = GameState:GetAttribute("Status") or "Waiting"
	local timer = GameState:GetAttribute("Timer") or 0
	if status == "Intermission" then
		statusLabel.Text = "Next wave in " .. timer .. "s"
	elseif status == "Wave" then
		statusLabel.Text = "Foxes left: " .. (GameState:GetAttribute("EnemiesLeft") or 0)
	elseif status == "Victory" then
		statusLabel.Text = "Victory! Restart in " .. timer .. "s"
	elseif status == "GameOver" then
		statusLabel.Text = "Burrow lost! Restart in " .. timer .. "s"
	else
		statusLabel.Text = "Waiting for players..."
	end

	local health = GameState:GetAttribute("BurrowHealth") or 0
	local maxHealth = GameState:GetAttribute("BurrowMaxHealth") or Config.Burrow.MaxHealth
	setBar(burrowBar, health, maxHealth, math.ceil(health) .. " / " .. maxHealth)
	local ratio = if maxHealth > 0 then health / maxHealth else 0
	burrowBar.Fill.BackgroundColor3 = COLORS.HealthLow:Lerp(COLORS.Health, ratio)

	local bossActive = GameState:GetAttribute("BossActive") == true
	bossFrame.Visible = bossActive
	if bossActive then
		local bossHealth = GameState:GetAttribute("BossHealth") or 0
		local bossMax = GameState:GetAttribute("BossMaxHealth") or 1
		setBar(bossBar, bossHealth, bossMax, math.ceil(bossHealth) .. " / " .. bossMax)
	end
end

local function refreshPlayer()
	local coins = player:GetAttribute("Coins") or 0
	coinsLabel.Text = "Coins: " .. coins
	local mana = player:GetAttribute("Mana") or 0
	local maxMana = player:GetAttribute("MaxMana") or Config.Mana.Max
	setBar(manaBar, mana, maxMana, math.floor(mana) .. " / " .. maxMana)
end

local function refreshCooldowns()
	local now = Workspace:GetServerTimeNow()
	local mana = player:GetAttribute("Mana") or 0
	for abilityName, ui in abilityButtons do
		local cfg = Config.Abilities[abilityName]
		local remaining = math.max(0, (player:GetAttribute("CD_" .. abilityName) or 0) - now)
		ui.Overlay.Size = UDim2.fromScale(1, math.clamp(remaining / cfg.Cooldown, 0, 1))
		if remaining > 0.05 then
			ui.Timer.Text = string.format("%.1f", remaining)
		elseif mana < (cfg.ManaCost or 0) then
			ui.Timer.Text = "No mana"
		else
			ui.Timer.Text = ""
		end
	end
end

function HUD.Init(onUseAbility: (string, boolean?) -> ())
	local playerGui = player:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("BunnyGuardianHUD")
	if existing then
		existing:Destroy()
	end
	screen = create("ScreenGui", {
		Name = "BunnyGuardianHUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})

	buildTop()
	buildBottomLeft()
	buildAbilities(onUseAbility)
	buildUpgrades()
	buildBanner()

	GameState.AttributeChanged:Connect(refreshGameState)
	player.AttributeChanged:Connect(function(attribute: string)
		if attribute == "Coins" or attribute:sub(1, 8) == "Upgrade_" then
			refreshUpgrades()
		end
		refreshPlayer()
	end)
	NotifyRemote.OnClientEvent:Connect(showBanner)
	RunService.RenderStepped:Connect(refreshCooldowns)

	refreshGameState()
	refreshPlayer()
	refreshUpgrades()
	showBanner("Protect the burrow from the foxes!", "info")
end

return HUD
