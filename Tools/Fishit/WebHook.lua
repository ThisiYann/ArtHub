local WebhookModule = {}

--// SERVICES
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Player = Players.LocalPlayer

--// FALLBACK LOGO
local LOGO_URL = "https://cdn.discordapp.com/attachments/1440154438105825413/1459710099596640296/content.png"

--// HTTP REQUEST
_G.httpRequest =
    (syn and syn.request)
    or (http and http.request)
    or http_request
    or (fluxus and fluxus.request)
    or request

--// CONFIG
_G.WebhookFlags = _G.WebhookFlags or {
    FishCaught = { Enabled = false, URL = "" },
    Stats      = { Enabled = false, URL = "", Delay = 5 },
    Disconnect = { Enabled = false, URL = "" }
}

_G.WebhookCustomName     = _G.WebhookCustomName or ""
_G.DiscordPingID         = _G.DiscordPingID or ""
_G.DisconnectCustomName  = _G.DisconnectCustomName or ""
_G.WebhookRarities       = _G.WebhookRarities or {}
_G.WebhookFishNames      = _G.WebhookFishNames or {}

--// TIER DATA
local TierNames = {
    [0] = "Common",
    [1] = "Common",
    [2] = "Uncommon",
    [3] = "Rare",
    [4] = "Epic",
    [5] = "Legendary",
    [6] = "Mythic",
    [7] = "Secret",

    Common = "Common",
    Uncommon = "Uncommon",
    Rare = "Rare",
    Epic = "Epic",
    Legendary = "Legendary",
    Mythic = "Mythic",
    Secret = "Secret"
}

local TierColors = {
    Common    = 0xbdc3c7,
    Uncommon  = 0x2ecc71,
    Rare      = 0x3498db,
    Epic      = 0x9b59b6,
    Legendary = 0xffff00,
    Mythic    = 0xff0000,
    Secret    = 0x00ffcc
}

local FishDatabase = {}
local disconnectHandled = false

--// UTIL
function WebhookModule.GetTierName(tier)
    return TierNames[tier] or "Unknown"
end

function WebhookModule.GetTierColor(tier)
    return TierColors[tier] or 0x34495e
end

--// WEBHOOK SENDER (SAFE LOCK)
function WebhookModule.SendWebhook(url, data)
    if not _G.httpRequest or not url or url == "" then
        return false
    end

    _G._WebhookLock = _G._WebhookLock or {}
    if _G._WebhookLock[url] then return false end

    _G._WebhookLock[url] = true

    local ok = pcall(function()
        _G.httpRequest({
            Url = url,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(data)
        })
    end)

    task.delay(1, function()
        _G._WebhookLock[url] = nil
    end)

    return ok
end

--// FISH DATABASE
function WebhookModule.BuildFishDatabase()
    local items = ReplicatedStorage:FindFirstChild("Items")
    if not items then return 0 end

    local count = 0

    for _, module in ipairs(items:GetChildren()) do
        if module:IsA("ModuleScript") then
            local ok, data = pcall(require, module)
            if ok and data and data.Data then
                local d = data.Data
                if (d.Type == "Fish" or d.Type == "Fishes") and d.Id and d.Name then
                    FishDatabase[d.Id] = {
                        Name = d.Name,
                        Tier = d.Tier or 0,
                        Icon = d.Icon or 0,
                        SellPrice = data.SellPrice or 0
                    }
                    count += 1
                end
            end
        end
    end

    return count
end

--// IMAGE RESOLVER
function WebhookModule.GetImgUrl(iconId)
    local id = tonumber(tostring(iconId):match("%d+"))
    if not id then return LOGO_URL end

    local api = "https://thumbnails.roblox.com/v1/assets?assetIds=" .. id .. "&size=420x420&format=Png"
    local url = LOGO_URL

    pcall(function()
        local res = HttpService:JSONDecode(game:HttpGet(api))
        url = res.data[1].imageUrl or url
    end)

    return url
end

--// FISH WEBHOOK
function WebhookModule.SendFishWebhook(fishId, metadata, data)
    if not _G.WebhookFlags.FishCaught.Enabled then return end

    local fish = FishDatabase[fishId]
    if not fish then return end

    local tierName = WebhookModule.GetTierName(fish.Tier)

    if #_G.WebhookRarities > 0 and not table.find(_G.WebhookRarities, tierName) then
        return
    end

    if #_G.WebhookFishNames > 0 and not table.find(_G.WebhookFishNames, fish.Name) then
        return
    end

    local weight =
        metadata and metadata.Weight
        or data?.InventoryItem?.Metadata?.Weight

    local playerName = _G.WebhookCustomName ~= "" and _G.WebhookCustomName or Player.Name

    local payload = {
        username = "ArtHub",
        embeds = {{
            title = "🎣 FISH CAUGHT",
            color = WebhookModule.GetTierColor(tierName),
            description = ("**%s** caught **%s**"):format(playerName, fish.Name),
            thumbnail = { url = WebhookModule.GetImgUrl(fish.Icon) },
            fields = {
                { name = "Tier", value = tierName, inline = true },
                { name = "Weight", value = weight and string.format("%.2f Kg", weight) or "N/A", inline = true }
            },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }}
    }

    WebhookModule.SendWebhook(_G.WebhookFlags.FishCaught.URL, payload)
end

--// DISCONNECT
function WebhookModule.SendDisconnectWebhook(reason)
    if disconnectHandled then return end
    disconnectHandled = true

    local name = _G.DisconnectCustomName ~= "" and _G.DisconnectCustomName or Player.Name

    WebhookModule.SendWebhook(_G.WebhookFlags.Disconnect.URL, {
        embeds = {{
            title = "⚠️ Disconnected",
            description = name .. " disconnected",
            fields = {
                { name = "Reason", value = reason or "Unknown" }
            },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }}
    })

    task.delay(5, function()
        TeleportService:Teleport(game.PlaceId, Player)
    end)
end

--// INIT
function WebhookModule.Initialize()
    WebhookModule.BuildFishDatabase()
    WebhookModule.SetupFishListener()
    WebhookModule.SetupDisconnectDetection()
    return WebhookModule
end

return WebhookModule
