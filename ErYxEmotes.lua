-- ErYx Emotes V4.4
-- OPEN SOURCE FOREVER!

pcall(function()
	local b = game:GetService("Lighting"):FindFirstChild("ErYxGlassBlur")
	if b then b:Destroy() end
end)
pcall(function()
	local f = workspace:FindFirstChild("ErYxGlassBlurFolder")
	if f then f:Destroy() end
end)
local _genv = (type(getgenv) == "function") and getgenv or function() return {} end
if _genv().ErYxEmotesCleanup then
	pcall(_genv().ErYxEmotesCleanup)
	_genv().ErYxEmotesCleanup = nil
end

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui", 10)
if not playerGui then return end

local old = playerGui:FindFirstChild("ErYxEmotes")
if old then old:Destroy() end

local DATA_FILE = "ErYxEmotes_Data.json"
local Settings = {theme = "Purple", speed = 1, notifications = true, loopEmote = true, language = nil, copyEmoteEnabled = false, stopOnWalk = true, showHUD = true}

local Favorites = {}
local RecentEmotes = {}
local _savePending = false
local function SaveData()
	if _savePending then return end
	_savePending = true
	task.delay(0.25, function()
		_savePending = false
		pcall(function()
			if writefile then
				writefile(DATA_FILE, HttpService:JSONEncode({
					favorites = Favorites,
					recent = RecentEmotes,
					settings = Settings
				}))
			end
		end)
	end)
end

local function LoadData()
	pcall(function()
		if readfile and isfile and isfile(DATA_FILE) then
			local data = HttpService:JSONDecode(readfile(DATA_FILE))
			if data then
				Favorites = data.favorites or {}
				RecentEmotes = data.recent or {}
				if data.settings then
					Settings.theme = data.settings.theme or "Purple"
					Settings.speed = data.settings.speed or 1
					Settings.notifications = data.settings.notifications ~= false
					Settings.loopEmote = data.settings.loopEmote ~= false
					Settings.stopOnWalk = data.settings.stopOnWalk ~= false
					Settings.showHUD = data.settings.showHUD ~= false
				end
			end
		end
	end)
end

LoadData()

local Themes = {
	Purple = {
		primary = Color3.fromRGB(10, 6, 18),
		secondary = Color3.fromRGB(20, 13, 34),
		tertiary = Color3.fromRGB(28, 18, 48),
		accent = Color3.fromRGB(138, 43, 226),
		text = Color3.fromRGB(255, 255, 255),
		textDim = Color3.fromRGB(180, 155, 220),
		stroke = Color3.fromRGB(138, 43, 226),
		strokeHover = Color3.fromRGB(186, 85, 255)
	}
}

local currentTheme = Themes.Purple
local selectedCard = nil
local nowPlayingLabel = nil

local function Notify(title, text)
	if not Settings.notifications then return end
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {Title = title, Text = text, Duration = 3})
	end)
end

local char = player.Character or player.CharacterAdded:Wait()
local hum = char:WaitForChild("Humanoid", 5)
if not hum or hum.RigType == Enum.HumanoidRigType.R6 then
	Notify("❌", "R15 only!")
	return
end

local Emotes = {}
local function LoadEmotes()
	local success, result = pcall(function()
		local response = game:HttpGet("https://raw.githubusercontent.com/zyrovell/Vexro/main/data/emotes.json")
		return HttpService:JSONDecode(response)
	end)
	
	if success and result then
		local data = type(result) == "table" and (result.data or result)
		local _seenIds = {}
		for _, emote in ipairs(data) do
			if emote.id and emote.name then
				local numId = tonumber(emote.id)
				if numId and not _seenIds[numId] then
					_seenIds[numId] = true
					Emotes[#Emotes + 1] = {name = tostring(emote.name), id = numId}
				end
			end
		end
	end
	
	if #Emotes == 0 then
		Emotes = {
			{name = "Wave", id = 3576686446},
			{name = "Point", id = 3576823880},
			{name = "Dance", id = 3576720708},
			{name = "Laugh", id = 3576777185},
			{name = "Cheer", id = 3576738018}
		}
	end
end

LoadEmotes()

local currentAnimTrack = nil

local function GetAnimator()
	local character = player.Character
	if not character then return nil end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return nil end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	return animator
end

local function UpdateNowPlaying(name)
	if nowPlayingLabel then
		if name then
			nowPlayingLabel.Text = "Now Playing: ".. name
			nowPlayingLabel.Parent.Visible = true
		else
			nowPlayingLabel.Parent.Visible = false
		end
	end
end

local function StopAllTracks()
	local animator = GetAnimator()
	if animator then
		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
			pcall(function() track:Stop(0.1) end)
		end
	end
	currentAnimTrack = nil
	UpdateNowPlaying(nil)
	if selectedCard then
		local s = selectedCard:FindFirstChildOfClass("UIStroke")
		if s then s.Thickness = 1 s.Color = currentTheme.stroke end
		selectedCard = nil
	end
end

local _animCache = {}

local function PlayEmote(id, name, card)
	local animator = GetAnimator()
	if not animator then return end
	
	StopAllTracks()
	
	local success = pcall(function()
		local anim = _animCache[id]
		if not anim then
			anim = Instance.new("Animation")
			anim.AnimationId = "rbxassetid://".. id
			_animCache[id] = anim
		end
		
		local track = animator:LoadAnimation(anim)
		track.Priority = Enum.AnimationPriority.Action4
		track.Looped = Settings.loopEmote
		track:Play(0.1)
		track:AdjustSpeed(Settings.speed)
		currentAnimTrack = track
		
		UpdateNowPlaying(name)
		
		if card then
			selectedCard = card
			local s = card:FindFirstChildOfClass("UIStroke")
			if s then
				s.Color = currentTheme.accent
				s.Thickness = 3
			end
		end
	end)
	
	if not success then
		Notify("❌", "Failed to load emote!")
	end
end

local gui = Instance.new("ScreenGui")
gui.Name = "ErYxEmotes"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = playerGui

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 600, 0, 480)
main.Position = UDim2.fromScale(0.5, 0.5)
main.AnchorPoint = Vector2.new(0.5, 0.5)
main.BackgroundColor3 = currentTheme.primary
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 20)

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = currentTheme.accent
mainStroke.Thickness = 2
mainStroke.Parent = main

local searchBox = Instance.new("TextBox")
searchBox.Size = UDim2.new(1, -20, 0, 35)
searchBox.Position = UDim2.new(0, 10, 0, 10)
searchBox.BackgroundColor3 = currentTheme.secondary
searchBox.Text = ""
searchBox.PlaceholderText = "Search..."
searchBox.TextColor3 = currentTheme.text
searchBox.Font = Enum.Font.Gotham
searchBox.TextSize = 14
searchBox.Parent = main
Instance.new("UICorner", searchBox).CornerRadius = UDim.new(0, 8)

local searchStroke = Instance.new("UIStroke")
searchStroke.Color = currentTheme.accent
searchStroke.Thickness = 1
searchStroke.Parent = searchBox

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -20, 1, -100)
scroll.Position = UDim2.new(0, 10, 0, 55)
scroll.BackgroundTransparency = 1
scroll.ScrollBarThickness = 4
scroll.Parent = main

local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.new(0, 75, 0, 95)
grid.CellPadding = UDim2.new(0, 6, 0, 6)
grid.Parent = scroll

local nowPlayingFrame = Instance.new("Frame")
nowPlayingFrame.Size = UDim2.new(1, -20, 0, 30)
nowPlayingFrame.Position = UDim2.new(0, 10, 1, -40)
nowPlayingFrame.BackgroundColor3 = currentTheme.secondary
nowPlayingFrame.Visible = false
nowPlayingFrame.Parent = main
Instance.new("UICorner", nowPlayingFrame).CornerRadius = UDim.new(0, 8)

local nowPlayingStroke = Instance.new("UIStroke")
nowPlayingStroke.Color = currentTheme.accent
nowPlayingStroke.Thickness = 2
nowPlayingStroke.Parent = nowPlayingFrame

nowPlayingLabel = Instance.new("TextLabel")
nowPlayingLabel.Size = UDim2.new(1, -10, 1, 0)
nowPlayingLabel.Position = UDim2.new(0, 5, 0, 0)
nowPlayingLabel.BackgroundTransparency = 1
nowPlayingLabel.Text = "Now Playing: None"
nowPlayingLabel.TextColor3 = currentTheme.text
nowPlayingLabel.Font = Enum.Font.GothamBold
nowPlayingLabel.TextSize = 13
nowPlayingLabel.TextXAlignment = Enum.TextXAlignment.Left
nowPlayingLabel.Parent = nowPlayingFrame

local function RefreshCards(filter)
	for _, child in ipairs(scroll:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end
	
	for _, emote in ipairs(Emotes) do
		if not filter or emote.name:lower():find(filter:lower()) then
			local card = Instance.new("TextButton")
			card.BackgroundColor3 = currentTheme.secondary
			card.Text = ""
			card.Parent = scroll
			Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
			
			local cardStroke = Instance.new("UIStroke")
			cardStroke.Color = currentTheme.stroke
			cardStroke.Thickness = 1
			cardStroke.Parent = card
			
			local img = Instance.new("ImageLabel")
			img.Size = UDim2.new(1, -10, 0, 55)
			img.Position = UDim2.new(0, 5, 0, 5)
			img.BackgroundTransparency = 1
			img.Image = "rbxthumb://type=Asset&id="..emote.id.."&w=420&h=420"
			img.Parent = card
			Instance.new("UICorner", img).CornerRadius = UDim.new(0, 6)
			
			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.new(1, -4, 0, 30)
			lbl.Position = UDim2.new(0, 2, 1, -32)
			lbl.BackgroundTransparency = 1
			lbl.Text = emote.name
			lbl.TextColor3 = currentTheme.text
			lbl.Font = Enum.Font.Gotham
			lbl.TextSize = 11
			lbl.TextWrapped = true
			lbl.Parent = card
			
			card.MouseButton1Click:Connect(function()
				PlayEmote(emote.id, emote.name, card)
			end)
		end
	end
end

searchBox:GetPropertyChangedSignal("Text"):Connect(function()
	RefreshCards(searchBox.Text)
end)

RefreshCards()
Notify("✅", "Loaded ".. #Emotes.. " emotes")
