local WebhookModule = {}

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer

-- Mengambil fungsi request dari berbagai executor
_G.httpRequest = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request

_G.WebhookFlags = _G.WebhookFlags or {
    FishCaught = { Enabled = false, URL = "" },
    Stats = { Enabled = false, URL = "", Delay = 5 },
    Disconnect = { Enabled = false, URL = "" }
}

local LOGO_URL = "https://cdn.discordapp.com/attachments/1440154438105825413/1459710099596640296/content.png"

_G.WebhookCustomName = _G.WebhookCustomName or ""
_G.DiscordPingID = _G.DiscordPingID or ""
_G.DisconnectCustomName = _G.DisconnectCustomName or ""
_G.WebhookRarities = _G.WebhookRarities or {}
_G.WebhookFishNames = _G.WebhookFishNames or {}

local TierNames = {
    ["Common"] = "Common", ["Uncommon"] = "Uncommon", ["Rare"] = "Rare",
    ["Epic"] = "Epic", ["Legendary"] = "Legendary", ["Mythic"] = "Mythic", ["Secret"] = "Secret",
    [0] = "Common", [1] = "Common", [2] = "Uncommon", [3] = "Rare", 
    [4] = "Epic", [5] = "Legendary", [6] = "Mythic", [7] = "Secret"
}

local FishDatabase = {}

function WebhookModule.GetTierColor(tierName)
    local colors = {
        ["Common"]    = 0xbdc3c7,
        ["Uncommon"]  = 0x2ecc71,
        ["Rare"]      = 0x3498db,
        ["Epic"]      = 0x9b59b6,
        ["Legendary"] = 0xffff00,
        ["Mythic"]    = 0xff0000,
        ["Secret"]    = 0x00ffcc
    }
    return colors[tierName] or 0x34495e
end

function WebhookModule.SendWebhook(url, data)
    if not _G.httpRequest or not url or url == "" then return false end

    _G._WebhookLock = _G._WebhookLock or {}
    if _G._WebhookLock[url] then return false end

    _G._WebhookLock[url] = true
    task.delay(1, function() _G._WebhookLock[url] = nil end)

    local success, err = pcall(function()
        return _G.httpRequest({
            Url = url,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(data)
        })
    end)
    return success
end

function WebhookModule.BuildFishDatabase()
    local itemsFolder = ReplicatedStorage:FindFirstChild("Items")
    if not itemsFolder then return 0 end

    local count = 0
    for _, item in ipairs(itemsFolder:GetChildren()) do
        if item:IsA("ModuleScript") then
            local success, data = pcall(require, item)
            if success and type(data) == "table" and data.Data then
                local fishData = data.Data
                if fishData.Type == "Fish" or fishData.Type == "Fishes" then
                    if fishData.Id and fishData.Name then
                        FishDatabase[fishData.Id] = {
                            Name = fishData.Name,
                            Tier = fishData.Tier or 0,
                            Icon = fishData.Icon or "",
                            SellPrice = data.SellPrice or 0
                        }
                        count = count + 1
                    end
                end
            end
        end
    end
    return count
end

function WebhookModule.GetImgUrl(idIcon)
    if not idIcon or idIcon == 0 or idIcon == "" then return LOGO_URL end
    local cleanId = tostring(idIcon):match("%d+")
    if not cleanId then return LOGO_URL end

    local finalUrl = LOGO_URL
    pcall(function()
        local response = game:HttpGet("https://thumbnails.roblox.com/v1/assets?assetIds=" .. cleanId .. "&type=Asset&size=420x420&format=Png")
        local data = HttpService:JSONDecode(response)
        if data and data.data and data.data[1] then
            finalUrl = data.data[1].imageUrl
        end
    end)
    return finalUrl
end

function WebhookModule.GetTierName(tier)
    return TierNames[tier] or "Unknown"
end

function WebhookModule.GetVariantName(fishId, metadata, data)
    local variant = "None"
    local mData = metadata or (data and data.InventoryItem and data.InventoryItem.Metadata)
    if mData and mData.VariantId and mData.VariantId ~= "" then
        variant = mData.VariantId
    end
    return variant
end

function WebhookModule.SendFishWebhook(fishId, metadata, data)
    if not _G.WebhookFlags.FishCaught.Enabled then return end
    local webhookUrl = _G.WebhookFlags.FishCaught.URL
    if not webhookUrl or webhookUrl == "" then return end

    local fishData = FishDatabase[fishId]
    if not fishData then return end

    local tierName = WebhookModule.GetTierName(fishData.Tier)

    -- Filter Rarity
    if _G.WebhookRarities and #_G.WebhookRarities > 0 then
        if not table.find(_G.WebhookRarities, tierName) then return end
    end

    -- Filter Nama Ikan
    if _G.WebhookFishNames and #_G.WebhookFishNames > 0 then
        if not table.find(_G.WebhookFishNames, fishData.Name) then return end
    end

    local weight = "N/A"
    local mData = metadata or (data and data.InventoryItem and data.InventoryItem.Metadata)
    if mData and mData.Weight then
        weight = string.format("%.2f Kg", mData.Weight)
    end

    local variant = WebhookModule.GetVariantName(fishId, metadata, data)
    local playerName = _G.WebhookCustomName ~= "" and _G.WebhookCustomName or Player.DisplayName

    local payload = {
        username = "ArtHub",
        avatar_url = LOGO_URL,
        embeds = {{
            title = "🎊 Catch Fish",
            description = "Congratulations! You just reeled in a catch from the deep!",
            color = WebhookModule.GetTierColor(tierName),
            author = {
                name = "ArtHub Notify",
                url = "https://discord.gg/your-link",
                icon_url = LOGO_URL
            },
            fields = {
                { name = "👤 UserName", value = "```".. playerName .."```", inline = true },
                { name = "🐟 Fish Name", value = "```".. fishData.Name .."```", inline = true },
                { name = "✨ Rarity", value = "```".. tierName .."```", inline = true },
                { name = "⚖️ Weight", value = "```".. weight .."```", inline = true },
                { name = "🧬 Mutation", value = "```".. variant .."```", inline = true },
                { name = "💰 Price", value = "```".. (fishData.SellPrice or 0) .."```", inline = true }
            },
            thumbnail = { url = WebhookModule.GetImgUrl(fishData.Icon) },
            footer = { text = "ArtHub Fishing System • Keep casting!", icon_url = LOGO_URL }
        }}
    }
    WebhookModule.SendWebhook(webhookUrl, payload)
end

-- ... [Sisa fungsi Disconnect & Listener tetap sama, hanya perbaikan kecil pada referensi variabel] ...

function WebhookModule.SetupFishListener()
    if _G.FishWebhookConnected then return end
    _G.FishWebhookConnected = true

    local NetFolder = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("sleitnick_net@0.2.0"):WaitForChild("net")
    local REObtainedNewFishNotification = NetFolder:WaitForChild("RE/ObtainedNewFishNotification")

    REObtainedNewFishNotification.OnClientEvent:Connect(function(fishId, _, data)
        task.spawn(function()
            local metadata = data and data.InventoryItem and data.InventoryItem.Metadata
            WebhookModule.SendFishWebhook(fishId, metadata, data)
        end)
    end)
end

function WebhookModule.Initialize()
    WebhookModule.BuildFishDatabase()
    WebhookModule.SetupFishListener()
    -- WebhookModule.SetupDisconnectDetection() -- Aktifkan jika ingin deteksi DC
    return WebhookModule
end

return WebhookModule
