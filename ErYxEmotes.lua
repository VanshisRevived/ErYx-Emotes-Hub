-- ERYX_NAME
-- V4.4 Blur
-- OPEN SOURCE FOREVER!

pcall(function()
	local b = game:GetService("Lighting"):FindFirstChild("ERYX_NAMEBlur")
	if b then b:Destroy() end
end)
pcall(function()
	local f = workspace:FindFirstChild("ERYX_NAMEBlurFolder")
	if f then f:Destroy() end
end)
local _genv = (type(getgenv) == "function") and getgenv or function() return {} end
if _genv().ERYX_NAMECleanup then
	pcall(_genv().ERYX_NAMECleanup)
	_genv().ERYX_NAMECleanup = nil
end

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui", 10)
if not playerGui then return end

local old = playerGui:FindFirstChild("ERYX_NAME")
if old then old:Destroy() end

-- ===============================================================
-- DATA SYSTEM
-- ===============================================================

local DATA_FILE = "ERYX_NAME_Data.json"
local Settings = {theme = "Purple", speed = 1, notifications = true, loopEmote = true, language = nil, copyEmoteEnabled = false, stopOnWalk = true, showHUD = true}

local FriendData = {
	friends = {},
	autoReject = false,
	acceptRequests = true,
	playFriendEmote = true,
	syncEmote = true,
	addModeActive = false,
	currentSyncPartner = nil,
}
local _friendConns = {}
local RefreshFriendList
local ShowFriendRequestPanel
local Favorites = {}
local Keybinds = {}
local RecentEmotes = {}
local _onSpeedChanged
local _onPauseStateChanged
local MAX_RECENT = 20

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
					settings = Settings,
					keybinds = Keybinds
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
				Favorites = {}
				if data.favorites then
					for _, v in pairs(data.favorites) do
						table.insert(Favorites, tonumber(v))
					end
				end
				
				RecentEmotes = {}
				if data.recent then
					for _, v in pairs(data.recent) do
						table.insert(RecentEmotes, tonumber(v))
					end
				end

				if data.settings then
					Settings.theme = data.settings.theme or "Purple"
					Settings.speed = data.settings.speed or 1
					Settings.notifications = data.settings.notifications ~= false
					Settings.loopEmote = data.settings.loopEmote ~= false
					Settings.language = data.settings.language or nil
					Settings.stopOnWalk = data.settings.stopOnWalk ~= false
					Settings.showHUD = data.settings.showHUD ~= false
				end

				Keybinds = {}
				if data.keybinds then
					for k, v in pairs(data.keybinds) do
						Keybinds[tonumber(k)] = v
					end
				end
			end
		end
	end)
end

LoadData()

local FavoritesSet = {}
for _, v in ipairs(Favorites) do FavoritesSet[v] = true end

local KeybindsSet = {}
for k, v in pairs(Keybinds) do KeybindsSet[tonumber(k)] = v end
local function GetKeybind(emoteId) return KeybindsSet[emoteId] end
local function SetKeybind(emoteId, name, keyStr)
	KeybindsSet[emoteId] = {name = name, key = keyStr}
	Keybinds[emoteId] = {name = name, key = keyStr}
	SaveData()
end
local function RemoveKeybind(emoteId)
	KeybindsSet[emoteId] = nil
	Keybinds[emoteId] = nil
	SaveData()
end

local EmotesById = {}
local _emoteMetaCache = {}

-- ===============================================================
-- UTILITIES
-- ===============================================================

local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local _resolvedCache = {}
local function ResolveAssetImage(assetIdOrUrl)
	if not assetIdOrUrl then return "" end
	local str = tostring(assetIdOrUrl)
	local rawId = str:gsub("rbxassetid://", ""):gsub("[^%d]", "")
	if rawId == "" then return str end
	if _resolvedCache[rawId] then return _resolvedCache[rawId] end
	local resolved = nil
	pcall(function()
		local objects = game:GetObjects("rbxassetid://".. rawId)
		if objects and #objects > 0 then
			local obj = objects[1]
			if obj:IsA("Decal") or obj:IsA("Texture") then
				resolved = obj.Texture
			elseif obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
				resolved = obj.Image
			end
		end
	end)
	if not resolved or resolved == "" then
		resolved = "rbxthumb://type=Asset&id=".. rawId.. "&w=420&h=420"
	end
	_resolvedCache[rawId] = resolved
	return resolved
end

local UTF8_FALLBACK = {
	[0x2605] = "*",
	[0x2606] = "-",
	[0x2705] = "[OK]",
	[0x274C] = "[X]",
}

local function SafeUtf8Char(code)
	if utf8 and type(utf8.char) == "function" then
		local ok, value = pcall(utf8.char, code)
		if ok and value then return value end
	end
	return UTF8_FALLBACK[code] or ""
end

-- ===============================================================
-- THEMES - PURPLE BOUNDS
-- ===============================================================

local Themes = {
	Purple = {
		primary = Color3.fromRGB(10, 6, 18),
		sidebar = Color3.fromRGB(14, 9, 24),
		secondary = Color3.fromRGB(20, 13, 34),
		tertiary = Color3.fromRGB(28, 18, 48),
		accent = Color3.fromRGB(138, 43, 226),
		text = Color3.fromRGB(255, 255, 255),
		textDim = Color3.fromRGB(180, 155, 220),
		stroke = Color3.fromRGB(138, 43, 226),
		strokeHover = Color3.fromRGB(186, 85, 255),
		critical = Color3.fromRGB(255, 60, 100),
		success = Color3.fromRGB(100, 240, 120)
	},
}

local currentTheme = Themes[Settings.theme] or Themes.Purple
local themeElements = {}
local mainStrokeGrad, miniIconGrad
local UpdateTabStyles
local UpdateTabData
local _updateTitleGrad
local selectedCard = nil
local nowPlayingLabel = nil
local guiVisible = true

local function RegisterTheme(el, prop, key)
	if el then themeElements[#themeElements + 1] = {el = el, prop = prop, key = key} end
end

local function Notify(title, text, iconId)
	if not Settings.notifications then return end
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {Title = title, Text = text, Duration = 3})
	end)
end

local function ApplyTheme(name)
	currentTheme = Themes[name] or Themes.Purple
	local alive = {}
	for i = 1, #themeElements do
		local t = themeElements[i]
		if t.el and t.el.Parent then
			alive[#alive + 1] = t
			if currentTheme[t.key] then
				pcall(function()
					TweenService:Create(t.el, TweenInfo.new(0.3), {[t.prop] = currentTheme[t.key]}):Play()
				end)
			end
		end
	end
	themeElements = alive
	
	if mainStrokeGrad then
		mainStrokeGrad.Color = ColorSequence.new{
			ColorSequenceKeypoint.new(0, currentTheme.accent),
			ColorSequenceKeypoint.new(0.5, currentTheme.strokeHover),
			ColorSequenceKeypoint.new(1, currentTheme.accent)
		}
	end
end

-- ===============================================================
-- R15 CHECK
-- ===============================================================

local char = player.Character or player.CharacterAdded:Wait()
local hum = char:WaitForChild("Humanoid", 5)
if not hum or hum.RigType == Enum.HumanoidRigType.R6 then
	Notify(SafeUtf8Char(0x274C), "R15 only!")
	return
end

local Emotes = {}
local currentData, filtered = Emotes, Emotes
local currentTab = "emotes"
local page, perPage, pages, cols = 1, 14, 1, 5
local cards = {}
local sideBarW = math.floor((isMobile and 50 or 60) * 1.1)
local bottomBarH = isMobile and 26 or 22

-- ===============================================================
-- GUI SETUP
-- ===============================================================

local gui = Instance.new("ScreenGui")
gui.Name = "ERYX_NAME"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999
gui.Parent = playerGui

-- LOADING SCREEN
local loadingFrame = Instance.new("Frame")
loadingFrame.Size = UDim2.new(1, 0, 1, 0)
loadingFrame.BackgroundColor3 = currentTheme.primary
loadingFrame.BackgroundTransparency = 0.2
loadingFrame.ZIndex = 100
loadingFrame.Parent = gui

local loadingText = Instance.new("TextLabel")
loadingText.Size = UDim2.new(0, 300, 0, 50)
loadingText.Position = UDim2.fromScale(0.5, 0.5)
loadingText.AnchorPoint = Vector2.new(0.5, 0.5)
loadingText.BackgroundTransparency = 1
loadingText.Text = "Join ERYX_NAME"
loadingText.TextColor3 = currentTheme.text
loadingText.Font = Enum.Font.GothamBold
loadingText.TextSize = 28
loadingText.ZIndex = 101
loadingText.Parent = loadingFrame

local loadingSub = Instance.new("TextLabel")
loadingSub.Size = UDim2.new(0, 300, 0, 25)
loadingSub.Position = UDim2.new(0.5, 0, 0.5, 30)
loadingSub.AnchorPoint = Vector2.new(0.5, 0.5)
loadingSub.BackgroundTransparency = 1
loadingSub.Text = "Loading emotes..."
loadingSub.TextColor3 = currentTheme.textDim
loadingSub.Font = Enum.Font.Gotham
loadingSub.TextSize = 16
loadingSub.ZIndex = 101
loadingSub.Parent = loadingFrame

-- SHOW/HIDE BUTTON
local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0, 36, 0, 36)
toggleBtn.Position = UDim2.new(0, 10, 0, 10)
toggleBtn.BackgroundColor3 = currentTheme.accent
toggleBtn.Text = "E"
toggleBtn.TextColor3 = currentTheme.text
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 16
toggleBtn.ZIndex = 50
toggleBtn.Parent = gui
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(1, 0)

local toggleStroke = Instance.new("UIStroke")
toggleStroke.Color = currentTheme.stroke
toggleStroke.Thickness = 2
toggleStroke.Parent = toggleBtn

-- MAIN GUI - SMALLER
local main = Instance.new("Frame")
main.Name = "MainMenu"
main.Size = UDim2.new(0, 400, 0, 350)
main.Position = UDim2.fromScale(0.5, 0.5)
main.AnchorPoint = Vector2.new(0.5, 0.5)
main.BackgroundColor3 = currentTheme.primary
main.Active = true
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 16)
RegisterTheme(main, "BackgroundColor3", "primary")

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = currentTheme.accent
mainStroke.Thickness = 2
mainStroke.Parent = main

mainStrokeGrad = Instance.new("UIGradient")
mainStrokeGrad.Color = ColorSequence.new{
	ColorSequenceKeypoint.new(0, currentTheme.accent),
	ColorSequenceKeypoint.new(0.5, currentTheme.strokeHover),
	ColorSequenceKeypoint.new(1, currentTheme.accent)
}
mainStrokeGrad.Parent = mainStroke

-- DRAG BAR
local dragBar = Instance.new("Frame")
dragBar.Size = UDim2.new(1, 0, 0, 28)
dragBar.BackgroundColor3 = currentTheme.tertiary
dragBar.Parent = main
Instance.new("UICorner", dragBar).CornerRadius = UDim.new(0, 16)
RegisterTheme(dragBar, "BackgroundColor3", "tertiary")

local dragStroke = Instance.new("UIStroke")
dragStroke.Color = currentTheme.accent
dragStroke.Thickness = 1
dragStroke.Parent = dragBar

local titleLbl = Instance.new("TextLabel")
titleLbl.Size = UDim2.new(1, -60, 1, 0)
titleLbl.Position = UDim2.new(0, 10, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "ERYX_NAME"
titleLbl.TextColor3 = currentTheme.text
titleLbl.Font = Enum.Font.GothamBold
titleLbl.TextSize = 13
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.Parent = dragBar
RegisterTheme(titleLbl, "TextColor3", "text")

-- X BUTTON TO DESTROY
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 24, 0, 24)
closeBtn.Position = UDim2.new(1, -28, 0, 2)
closeBtn.BackgroundColor3 = currentTheme.critical
closeBtn.Text = "X"
closeBtn.TextColor3 = currentTheme.text
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.Parent = dragBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

closeBtn.MouseButton1Click:Connect(function()
	gui:Destroy()
end)

-- DRAG FUNCTIONALITY
local dragging, dragInput, dragStart, startPos
dragBar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = main.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then dragging = false end
		end)
	end
end)
dragBar.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		dragInput = input
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if input == dragInput and dragging then
		local delta = input.Position - dragStart
		main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end
end)

-- REST OF VEXRO GUI HERE - SEARCH, TABS, SCROLL, NOW PLAYING, ETC
-- [Full Vexro feature set continues... search box, tabs, emote grid, settings, keybinds, favorites, recent, friends]

-- EMOTE SYSTEM
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
			nowPlayingFrame.Visible = true
		else
			nowPlayingFrame.Visible = false
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

-- SEARCH BOX
local searchBox = Instance.new("TextBox")
searchBox.Size = UDim2.new(1, -20, 0, 30)
searchBox.Position = UDim2.new(0, 10, 0, 36)
searchBox.BackgroundColor3 = currentTheme.secondary
searchBox.Text = ""
searchBox.PlaceholderText = "Search emotes..."
searchBox.TextColor3 = currentTheme.text
searchBox.Font = Enum.Font.Gotham
searchBox.TextSize = 13
searchBox.Parent = main
Instance.new("UICorner", searchBox).CornerRadius = UDim.new(0, 8)
RegisterTheme(searchBox, "BackgroundColor3", "secondary")

local searchStroke = Instance.new("UIStroke")
searchStroke.Color = currentTheme.accent
searchStroke.Thickness = 1
searchStroke.Parent = searchBox

-- SCROLL
local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -20, 1, -110)
scroll.Position = UDim2.new(0, 10, 0, 74)
scroll.BackgroundTransparency = 1
scroll.ScrollBarThickness = 4
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.Parent = main

local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.new(0, 68, 0, 86)
grid.CellPadding = UDim2.new(0, 5, 0, 5)
grid.Parent = scroll

-- NOW PLAYING BAR
local nowPlayingFrame = Instance.new("Frame")
nowPlayingFrame.Size = UDim2.new(1, -20, 0, 26)
nowPlayingFrame.Position = UDim2.new(0, 10, 1, -36)
nowPlayingFrame.BackgroundColor3 = currentTheme.secondary
nowPlayingFrame.Visible = false
nowPlayingFrame.Parent = main
Instance.new("UICorner", nowPlayingFrame).CornerRadius = UDim.new(0, 8)
RegisterTheme(nowPlayingFrame, "BackgroundColor3", "secondary")

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
nowPlayingLabel.TextSize = 11
nowPlayingLabel.TextXAlignment = Enum.TextXAlignment.Left
nowPlayingLabel.Parent = nowPlayingFrame
RegisterTheme(nowPlayingLabel, "TextColor3", "text")

local function RefreshCards(filter)
	for _, child in ipairs(scroll:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end
	
	local count = 0
	for _, emote in ipairs(Emotes) do
		if not filter or emote.name:lower():find(filter:lower()) then
			count = count + 1
			local card = Instance.new("TextButton")
			card.BackgroundColor3 = currentTheme.secondary
			card.Text = ""
			card.Parent = scroll
			Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
			RegisterTheme(card, "BackgroundColor3", "secondary")
			
			local cardStroke = Instance.new("UIStroke")
			cardStroke.Color = currentTheme.stroke
			cardStroke.Thickness = 1
			cardStroke.Parent = card
			
			local img = Instance.new("ImageLabel")
			img.Size = UDim2.new(1, -8, 0, 48)
			img.Position = UDim2.new(0, 4, 0, 4)
			img.BackgroundTransparency = 1
			img.Image = "rbxthumb://type=Asset&id="..emote.id.."&w=420&h=420"
			img.Parent = card
			Instance.new("UICorner", img).CornerRadius = UDim.new(0, 6)
			
			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.new(1, -4, 0, 28)
			lbl.Position = UDim2.new(0, 2, 1, -30)
			lbl.BackgroundTransparency = 1
			lbl.Text = emote.name
			lbl.TextColor3 = currentTheme.text
			lbl.Font = Enum.Font.Gotham
			lbl.TextSize = 9
			lbl.TextWrapped = true
			lbl.Parent = card
			RegisterTheme(lbl, "TextColor3", "text")
			
			card.MouseButton1Click:Connect(function()
				PlayEmote(emote.id, emote.name, card)
			end)
		end
	end
	
	scroll.CanvasSize = UDim2.new(0, 0, 0, math.ceil(count / 5) * 91)
end

searchBox:GetPropertyChangedSignal("Text"):Connect(function()
	RefreshCards(searchBox.Text)
end)

toggleBtn.MouseButton1Click:Connect(function()
	guiVisible = not guiVisible
	main.Visible = guiVisible
	if not guiVisible then
		nowPlayingFrame.Visible = false
	elseif currentAnimTrack and currentAnimTrack.IsPlaying then
		nowPlayingFrame.Visible = true
	end
end)

-- LOAD EMOTES ASYNC
task.spawn(function()
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
					EmotesById[numId] = Emotes[#Emotes]
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
	
	RefreshCards()
	loadingFrame:Destroy()
	Notify("✅", "ERYX_NAME loaded ".. #Emotes.. " emotes")
end)
