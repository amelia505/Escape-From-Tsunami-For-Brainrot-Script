--[[
    @author depso (depthso)
    @description Grow a Garden stock bot script
    https://www.roblox.com/games/126884695634066
]]

type table = {
	[any]: any
}

_G.Configuration = {
	--// Reporting
	["Enabled"] = true,
	["Webhook"] = "https://discord.com/api/webhooks.....", -- replace with your webhook url
	["Weather Reporting"] = true,
	
	--// User
	["Anti-AFK"] = true,
	["Auto-Reconnect"] = true,
	["Rendering Enabled"] = false,

	--// Embeds
	["AlertLayouts"] = {
		["Weather"] = {
			EmbedColor = Color3.fromRGB(42, 109, 255),
		},
		["SeedsAndGears"] = {
			EmbedColor = Color3.fromRGB(56, 238, 23),
			Layout = {
				["ROOT/SeedStock/Stocks"] = "SEEDS STOCK",
				["ROOT/GearStock/Stocks"] = "GEAR STOCK"
			}
		},
		["EventShop"] = {
			EmbedColor = Color3.fromRGB(212, 42, 255),
			Layout = {
				["ROOT/EventShopStock/Stocks"] = "EVENT STOCK"
			}
		},
		["Eggs"] = {
			EmbedColor = Color3.fromRGB(251, 255, 14),
			Layout = {
				["ROOT/PetEggStock/Stocks"] = "EGG STOCK"
			}
		},
		["CosmeticStock"] = {
			EmbedColor = Color3.fromRGB(255, 106, 42),
			Layout = {
				["ROOT/CosmeticStock/ItemStocks"] = "COSMETIC ITEMS STOCK"
			}
		}
	}
}

--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local VirtualUser = cloneref(game:GetService("VirtualUser"))
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

--// Remotes
local DataStream = ReplicatedStorage.GameEvents.DataStream -- RemoteEvent 
local WeatherEventStarted = ReplicatedStorage.GameEvents.WeatherEventStarted -- RemoteEvent 

local LocalPlayer = Players.LocalPlayer
local PlaceId = game.PlaceId
local JobId = game.JobId

local function GetConfigValue(Key: string)
	return _G.Configuration[Key]
end

--// Set rendering enabled
local Rendering = GetConfigValue("Rendering Enabled")
RunService:Set3dRenderingEnabled(Rendering)

--// Check if the script is already running
if _G.StockBot then return end 
_G.StockBot = true

local function ConvertColor3(Color: Color3): number
	local Hex = Color:ToHex()
	return tonumber(Hex, 16)
end

local function GetDataPacket(Data, Target: string)
	for _, Packet in Data do
		local Name = Packet[1]
		local Content = Packet[2]

		if Name == Target then
			return Content
		end
	end

	return 
end

local function GetLayout(Type: string)
	local Layouts = GetConfigValue("AlertLayouts")
	return Layouts[Type]
end

local function WebhookSend(Type: string, Fields: table)
	local Enabled = GetConfigValue("Enabled")
	local Webhook = GetConfigValue("Webhook")

	--// Check if reports are enabled
	if not Enabled then return end

	local Layout = GetLayout(Type)
	local Color = ConvertColor3(Layout.EmbedColor)

	--// Webhook data
	local TimeStamp = DateTime.now():ToIsoDate()
	local Body = {
		embeds = {
			{
				color = Color,
				fields = Fields,
				footer = {
					text = "Created by depso" -- Please keep
				},
				timestamp = TimeStamp
			}
		}
	}

	local RequestData = {
        Url = Webhook,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json"
        },
        Body = HttpService:JSONEncode(Body)
    }

	--// Send POST request to the webhook
	task.spawn(request, RequestData)
end

local function MakeStockString(Stock: table): string
	local String = ""
	for Name, Data in Stock do 
		local Amount = Data.Stock
		local EggName = Data.EggName 

		Name = EggName or Name
		String ..= `{Name} **x{Amount}**\n`
	end

	return String
end

local function ProcessPacket(Data, Type: string, Layout)
	local Fields = {}
	
	local FieldsLayout = Layout.Layout
	if not FieldsLayout then return end

	for Packet, Title in FieldsLayout do 
		local Stock = GetDataPacket(Data, Packet)
		if not Stock then return end

		local StockString = MakeStockString(Stock)
		local Field = {
			name = Title,
			value = StockString,
			inline = true
		}

		table.insert(Fields, Field)
	end

	WebhookSend(Type, Fields)
end

DataStream.OnClientEvent:Connect(function(Type: string, Profile: string, Data: table)
	if Type ~= "UpdateData" then return end
	if not Profile:find(LocalPlayer.Name) then return end

	local Layouts = GetConfigValue("AlertLayouts")
	for Name, Layout in Layouts do
		ProcessPacket(Data, Name, Layout)
	end
end)

WeatherEventStarted.OnClientEvent:Connect(function(Event: string, Length: number)
	--// Check if Weather reports are enabled
	local WeatherReporting = GetConfigValue("Weather Reporting")
	if not WeatherReporting then return end

	--// Calculate end unix
	local ServerTime = math.round(workspace:GetServerTimeNow())
	local EndUnix = ServerTime + Length

	WebhookSend("Weather", {
		{
			name = "WEATHER",
			value = `{Event}\nEnds:<t:{EndUnix}:R>`,
			inline = true
		}
	})
end)

--// Anti idle
LocalPlayer.Idled:Connect(function()
	--// Check if Anti-AFK is enabled
	local AntiAFK = GetConfigValue("Anti-AFK")
	if not AntiAFK then return end

	VirtualUser:CaptureController()
	VirtualUser:ClickButton2(Vector2.new())
end)

--// Auto reconnect
GuiService.ErrorMessageChanged:Connect(function()
	local IsSingle = #Players:GetPlayers() <= 1

	--// Check if Auto-Reconnect is enabled
	local AutoReconnect = GetConfigValue("Auto-Reconnect")
	if not AutoReconnect then return end

  --// Execute the script after teleporting
	queue_on_teleport("https://raw.githubusercontent.com/depthso/Grow-a-Garden/refs/heads/main/Stock%20bot.lua")

	--// Join a different server if the player is solo
	if IsSingle then
		TeleportService:Teleport(PlaceId, LocalPlayer)
		return
	end

	TeleportService:TeleportToPlaceInstance(PlaceId, JobId, LocalPlayer)
end)
