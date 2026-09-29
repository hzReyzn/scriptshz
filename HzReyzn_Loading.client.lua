--[[
    HzReyzn Hub | Prism loading screen
    Static artwork edition: no VideoFrame, video downloads, or decoder waits.

    The intro progress is a five-second animation, not a measure of game assets.
    Its clock runs independently of image downloads and always reaches 100%.
    Fade in: 1 second. "Loading completed": at least 2 seconds.
    Click/tap anywhere to dismiss with a slow downward fade.
    An early tap is remembered. Without a tap the animated screen stays open.

    Uses the supplied background and transparent version of the supplied logo.
    Local-image environments need getcustomasset (or getsynasset) + writefile.
    For Roblox Studio, upload the images and set the three optional asset IDs.
    All effects use normal GUI layers to keep the artwork and lettering sharp.
    Download jobs, input events, and animations are cleaned up on dismissal.
]]

local CONFIG = {
    FadeIn = 1,
    LoadDuration = 5,
    CompletedHold = 2,
    FadeOut = 1.4,
    SlidePixels = 62,
    BackgroundAssetId = "",
    LogoAssetId = "",
    GlowAssetId = "",
    Quality = "Auto", -- "Auto", "High", "Low"
    OnComplete = function()
        -- Open your main hub here after the user dismisses the intro.
    end,
}

local ROOT = "https://raw.githubusercontent.com/hzReyzn/scriptshz/refs/heads/main/assets/loading/"
local ASSETS = {
    background = {file = "hzreyzn-background-v4.jpg", cache = "HzReyzn_Background_v4.jpg", kind = "jpg", bytes = 397876},
    logo = {file = "hzreyzn-logo-v4.png", cache = "HzReyzn_Logo_v4.png", kind = "png", bytes = 1730191},
    glow = {file = "hzreyzn-glow-v4.png", cache = "HzReyzn_Glow_v4.png", kind = "png", bytes = 16297},
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Input = game:GetService("UserInputService")
local GUI_NAME = "HzReyzn_PrismLoading"
local PI2 = math.pi * 2
local C = {
    black = Color3.fromRGB(0, 0, 0),
    blue = Color3.fromRGB(74, 99, 255),
    violet = Color3.fromRGB(146, 73, 255),
    magenta = Color3.fromRGB(249, 58, 224),
    cyan = Color3.fromRGB(57, 221, 255),
    white = Color3.fromRGB(238, 239, 255),
    muted = Color3.fromRGB(175, 164, 202),
    deep = Color3.fromRGB(31, 15, 57),
}
local WHITE = Color3.fromRGB(255, 255, 255)
local PALETTE = {C.cyan, C.blue, C.violet, C.magenta, C.violet}

local function smooth(x)
    x = math.clamp(x, 0, 1)
    return x * x * (3 - 2 * x)
end

local function cycle(t)
    local p = (t % 1) * #PALETTE
    local i = math.floor(p)
    return PALETTE[i + 1]:Lerp(PALETTE[(i + 1) % #PALETTE + 1], smooth(p - i))
end

local function new(class, properties, parent)
    local object = Instance.new(class)
    for key, value in pairs(properties) do object[key] = value end
    object.Parent = parent
    return object
end

local function numbers(points)
    local keys = {}
    for i, point in ipairs(points) do keys[i] = NumberSequenceKeypoint.new(point[1], point[2]) end
    return NumberSequence.new(keys)
end

local function colors(list)
    local keys = {}
    for i, color in ipairs(list) do keys[i] = ColorSequenceKeypoint.new((i - 1) / (#list - 1), color) end
    return ColorSequence.new(keys)
end

local FLOW = colors({C.cyan, C.blue, C.violet, C.magenta})
local SOFT = numbers({{0, 1}, {0.18, 0.88}, {0.5, 0}, {0.82, 0.88}, {1, 1}})
local INWARD = numbers({{0, 0}, {0.13, 0.45}, {0.36, 0.82}, {0.65, 0.97}, {1, 1}})

local function contentId(value)
    value = tostring(value or "")
    if value == "" or value == "0" then return nil end
    return value:match("^%d+$") and ("rbxassetid://" .. value) or value
end

local function loadLocalAsset(asset, alive)
    local getAsset = getcustomasset or getsynasset
    if type(getAsset) ~= "function" or type(writefile) ~= "function" then return nil end
    local function valid(bytes)
        if type(bytes) ~= "string" or #bytes ~= asset.bytes then return false end
        if asset.kind == "jpg" then return bytes:sub(1, 2) == "\255\216" end
        return bytes:sub(1, 8) == "\137PNG\13\10\26\10"
    end
    if type(isfile) == "function" and type(readfile) == "function" then
        local readOK, bytes = pcall(function()
            return isfile(asset.cache) and readfile(asset.cache) or nil
        end)
        if readOK and valid(bytes) then
            local ok, uri = pcall(getAsset, asset.cache)
            if ok and type(uri) == "string" and uri ~= "" then return uri end
        end
    end
    local downloaded, bytes = pcall(function() return game:HttpGet(ROOT .. asset.file) end)
    if not alive() then return nil end
    if not downloaded or not valid(bytes) then
        warn("HzReyzn: could not load image " .. asset.file)
        return nil
    end
    local ok, uri = pcall(function()
        writefile(asset.cache, bytes)
        return getAsset(asset.cache)
    end)
    if not alive() then return nil end
    return ok and type(uri) == "string" and uri ~= "" and uri or nil
end

local function play()
    if not RunService:IsClient() then return end
    local player = Players.LocalPlayer
    local playerGui = player and player:WaitForChild("PlayerGui", 10)
    if not playerGui then return end
    local old = playerGui:FindFirstChild(GUI_NAME)
    if old then
        local stop = old:FindFirstChild("StopLoading")
        if stop and stop:IsA("BindableEvent") then stop:Fire() end
        if old.Parent then old:Destroy() end
    end

    local S = {
        alive = true, completed = false, elapsed = 0, tapped = false,
        connections = {}, tasks = {}, fades = {}, glowImages = {},
        backgroundAt = nil, logoAt = nil, glowAt = nil, completionAt = nil, dismissAt = nil,
    }
    local gui = new("ScreenGui", {
        Name = GUI_NAME, ResetOnSpawn = false, IgnoreGuiInset = true,
        DisplayOrder = 10000, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, playerGui)
    pcall(function() gui.ScreenInsets = Enum.ScreenInsets.None; gui.ClipToDeviceSafeArea = false end)

    local function cleanup(completed)
        if not S.alive then return end
        S.alive, S.completed = false, completed == true
        for _, connection in ipairs(S.connections) do connection:Disconnect() end
        for _, thread in ipairs(S.tasks) do
            if type(task.cancel) == "function" then pcall(task.cancel, thread) end
        end
        gui:Destroy()
        table.clear(S.connections)
        table.clear(S.tasks)
        table.clear(S.fades)
        table.clear(S.glowImages)
    end

    local stop = new("BindableEvent", {Name = "StopLoading"}, gui)
    S.connections[#S.connections + 1] = stop.Event:Connect(function() cleanup(false) end)
    S.connections[#S.connections + 1] = gui.Destroying:Connect(function() cleanup(false) end)

    local function fade(object, property, opacity, channel)
        local entry = {object = object, property = property, opacity = opacity, channel = channel or "fx", multiplier = 1, last = -1}
        object[property] = 1
        S.fades[#S.fades + 1] = entry
        return entry
    end

    local function frame(parent, name, pos, size, tint, opacity, z, channel)
        local f = new("Frame", {
            Name = name, Position = pos, Size = size, BackgroundColor3 = tint or C.black,
            BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = z or 1,
        }, parent)
        if opacity and opacity > 0 then fade(f, "BackgroundTransparency", opacity, channel) end
        return f
    end

    local function gradient(object, tint, alpha, angle)
        return new("UIGradient", {Color = tint or FLOW, Transparency = alpha or NumberSequence.new(0), Rotation = angle or 0}, object)
    end

    local function glow(parent, name, pos, size, tint, opacity, z)
        local image = new("ImageLabel", {
            Name = name, BackgroundTransparency = 1, ImageTransparency = 1,
            AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Size = size,
            ImageColor3 = tint, ScaleType = Enum.ScaleType.Stretch, ZIndex = z or 1,
        }, parent)
        S.glowImages[#S.glowImages + 1] = image
        return image, fade(image, "ImageTransparency", opacity, "glow")
    end

    local function light(parent, name, width, height, tint, opacity, z)
        local f = frame(parent, name, UDim2.fromOffset(0, 0), UDim2.fromOffset(width, height), tint, opacity, z)
        f.AnchorPoint = Vector2.new(0.5, 0.5)
        gradient(f, ColorSequence.new(WHITE), SOFT)
        return f
    end

    local function flare(parent, tint, size, z)
        local group = frame(parent, "SoftFlare", UDim2.fromOffset(0, 0), UDim2.fromOffset(1, 1), C.black, 0, z)
        glow(group, "FlareBloom", UDim2.fromOffset(0, 0), UDim2.fromOffset(size * 3, size * 3), tint, 0.35, 1)
        light(group, "HorizontalGlow", size * 2.4, 3, tint, 0.29, 2)
        light(group, "HorizontalCore", size * 2.1, 1, C.white, 0.68, 3)
        local v = light(group, "VerticalCore", size * 1.3, 1, C.white, 0.55, 3)
        v.Rotation = 90
        return group, new("UIScale", {Scale = 1}, group)
    end

    local function spawn(fn)
        local thread = task.spawn(function()
            local ok, problem = pcall(fn)
            if not ok and S.alive then warn("HzReyzn image: " .. tostring(problem)) end
        end)
        S.tasks[#S.tasks + 1] = thread
    end

    local ok, problem = xpcall(function()
        local low = CONFIG.Quality == "Low" or (CONFIG.Quality == "Auto" and Input.TouchEnabled)
        local rng = Random.new(4927)
        local root = frame(gui, "Scene", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), C.black, 1, 1, "back")
        root.ClipsDescendants = true
        local photo = new("ImageLabel", {
            Name = "BackgroundArtwork", BackgroundTransparency = 1, ImageTransparency = 1,
            AnchorPoint = Vector2.new(0.34, 0.5), ScaleType = Enum.ScaleType.Stretch,
            Size = UDim2.fromScale(1, 1), ZIndex = 1,
        }, root)
        fade(photo, "ImageTransparency", 1, "photo")
        gradient(photo, ColorSequence.new(WHITE), numbers({{0, 0.03}, {0.42, 0}, {0.65, 0.07}, {0.82, 0.5}, {1, 1}}))
        local photoScale = new("UIScale", {Scale = 1}, photo)
        local atmosphere = frame(root, "Atmosphere", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), C.black, 0, 2)
        local topVeil = frame(atmosphere, "TopFeather", UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.08), C.black, 1, 1, "back")
        gradient(topVeil, ColorSequence.new(WHITE), numbers({{0, 0}, {0.25, 0}, {1, 1}}), 90)
        local bottomVeil = frame(atmosphere, "BottomFeather", UDim2.fromScale(0, 0.92), UDim2.fromScale(1, 0.08), C.black, 1, 1, "back")
        gradient(bottomVeil, ColorSequence.new(WHITE), numbers({{0, 0}, {0.25, 0}, {1, 1}}), 270)

        local mist, mistAlpha = glow(atmosphere, "VioletMist", UDim2.fromScale(0.77, 0.44), UDim2.fromScale(0.7, 0.72), C.violet, 0.2, 2)
        local cyanMist = glow(atmosphere, "CyanMist", UDim2.fromScale(0.66, 0.76), UDim2.fromScale(0.59, 0.24), C.cyan, 0.12, 2)
        local pinkMist = glow(atmosphere, "MagentaMist", UDim2.fromScale(0.87, 0.34), UDim2.fromScale(0.48, 0.5), C.magenta, 0.16, 2)
        local mistScale = new("UIScale", {Scale = 1}, mist)

        local motes = {}
        for i = 1, low and 22 or 36 do
            local size = rng:NextNumber(0.9, 2.5)
            local tint = PALETTE[(i - 1) % #PALETTE + 1]
            local p = frame(atmosphere, "DriftingLight", UDim2.fromScale(0, 0), UDim2.fromOffset(size, size), tint, 0, 3)
            p.AnchorPoint, p.Rotation = Vector2.new(0.5, 0.5), 45
            motes[i] = {object = p, alpha = fade(p, "BackgroundTransparency", 0.72),
                x = rng:NextNumber(0.04, 0.96), y = rng:NextNumber(0, 1),
                phase = rng:NextNumber(0, PI2), speed = rng:NextNumber(0.008, 0.018)}
        end
        local streaks = {}
        for i = 1, 3 do
            local ray = light(atmosphere, "SilkRay", 110 + i * 28, 1, i == 2 and C.cyan or C.violet, 0, 3)
            ray.Rotation = -18
            streaks[i] = {object = ray, alpha = fade(ray, "BackgroundTransparency", 0.15)}
        end

        local frameLayer = frame(root, "FrameLayer", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), C.black, 0, 4)
        local border = frame(frameLayer, "LuminousFrame", UDim2.fromOffset(16, 16), UDim2.new(1, -32, 1, -32), C.black, 0, 1)
        local borderGradients = {}
        for i, spec in ipairs({{10, 0.035}, {5, 0.09}, {2.5, 0.24}, {1.1, 0.88}}) do
            local outline = frame(border, "FrameGlow", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), C.black, 0, i)
            local stroke = new("UIStroke", {Color = WHITE, Thickness = spec[1], ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, outline)
            fade(stroke, "Transparency", spec[2])
            borderGradients[i] = gradient(stroke, FLOW, nil, 25)
        end
        local edges = {}
        local edgeDefs = {
            {UDim2.fromScale(0, 0), UDim2.fromScale(0.1, 1), 0},
            {UDim2.fromScale(0.9, 0), UDim2.fromScale(0.1, 1), 180},
            {UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.12), 90},
            {UDim2.fromScale(0, 0.88), UDim2.fromScale(1, 0.12), 270},
        }
        for i, spec in ipairs(edgeDefs) do
            local edge = frame(border, "InwardGradient", spec[1], spec[2], C.violet, 0, 1)
            gradient(edge, ColorSequence.new(WHITE), INWARD, spec[3])
            edges[i] = {object = edge, alpha = fade(edge, "BackgroundTransparency", 0.19)}
        end
        local corners, cornerLines = {}, {}
        for i = 1, 4 do
            local corner = frame(border, "CornerAccent", UDim2.fromOffset(0, 0), UDim2.fromOffset(36, 36), C.black, 0, 5)
            cornerLines[#cornerLines + 1] = frame(corner, "Horizontal", UDim2.fromOffset(0, 0), UDim2.fromOffset(36, 1.7), C.cyan, 0.82, 1)
            cornerLines[#cornerLines + 1] = frame(corner, "Vertical", UDim2.fromOffset(0, 0), UDim2.fromOffset(1.7, 36), C.magenta, 0.82, 1)
            corners[i] = corner
        end
        local runners = {}
        for i = 1, 2 do
            local g, sc = flare(border, i == 1 and C.cyan or C.magenta, 17, 6)
            runners[i] = {object = g, scale = sc}
        end

        local logoGroup = frame(root, "FloatingLogo", UDim2.fromScale(0.75, 0.43), UDim2.fromOffset(620, 349), C.black, 0, 6)
        logoGroup.AnchorPoint = Vector2.new(0.5, 0.5)
        local logoScale = new("UIScale", {Scale = 1}, logoGroup)
        local _, logoShade = glow(logoGroup, "LogoSoftShade", UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1.3, 1.5), C.black, 0.8, 1)
        local logoAura, auraAlpha = glow(logoGroup, "LogoAura", UDim2.fromScale(0.5, 0.68), UDim2.fromScale(0.96, 0.65), C.violet, 0.4, 1)
        local auraScale = new("UIScale", {Scale = 1}, logoAura)
        local logo = new("ImageLabel", {
            Name = "TransparentLogo", BackgroundTransparency = 1, ImageTransparency = 1,
            Size = UDim2.fromScale(1, 1), ScaleType = Enum.ScaleType.Fit, ZIndex = 3,
        }, logoGroup)
        fade(logo, "ImageTransparency", 1, "logo")
        local fallback = new("TextLabel", {
            Name = "TitleFallback", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
            Font = Enum.Font.GothamBlack, Text = "HzReyzn Hub", TextScaled = true,
            TextColor3 = WHITE, TextStrokeTransparency = 1, ZIndex = 2,
        }, logoGroup)
        new("UITextSizeConstraint", {MinTextSize = 14, MaxTextSize = 58}, fallback)
        gradient(fallback, colors({C.cyan, C.white, C.magenta}))
        local fallbackAlpha = fade(fallback, "TextTransparency", 0.9)
        local flares = {}
        for i, point in ipairs({{0.13, 0.32}, {0.86, 0.28}, {0.56, 0.72}}) do
            local g, sc = flare(logoGroup, i == 2 and C.cyan or C.magenta, 12, 4)
            g.Position = UDim2.fromScale(point[1], point[2])
            flares[i] = sc
        end

        local progress = frame(root, "Progress", UDim2.fromScale(0.75, 0.73), UDim2.fromOffset(410, 82), C.black, 0, 7)
        progress.AnchorPoint = Vector2.new(0.5, 0)
        glow(progress, "ProgressSoftShade", UDim2.new(0.5, 0, 0, 28), UDim2.new(1.4, 0, 0, 140), C.black, 0.8, 1)
        glow(progress, "ProgressAura", UDim2.new(0.5, 0, 0, 34), UDim2.new(1.15, 0, 0, 74), C.violet, 0.23, 2)
        local status = new("TextLabel", {
            Name = "CompletionLabel", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 0),
            Size = UDim2.new(1, -65, 0, 24), Font = Enum.Font.GothamMedium,
            Text = "Loading", TextSize = 14, TextColor3 = C.muted,
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3,
        }, progress)
        fade(status, "TextTransparency", 1, "ui")
        local percentage = new("TextLabel", {
            Name = "Percentage", BackgroundTransparency = 1, Position = UDim2.new(1, -65, 0, -1),
            Size = UDim2.fromOffset(65, 24), Font = Enum.Font.GothamMedium,
            Text = "0%", TextSize = 18, TextColor3 = C.white,
            TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 3,
        }, progress)
        fade(percentage, "TextTransparency", 1, "ui")
        local track = frame(progress, "Track", UDim2.fromOffset(0, 32), UDim2.new(1, 0, 0, 5), C.deep, 0.95, 3, "ui")
        new("UICorner", {CornerRadius = UDim.new(1, 0)}, track)
        local trackStroke = new("UIStroke", {Color = C.violet, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, track)
        fade(trackStroke, "Transparency", 0.26, "ui")
        local fill = frame(track, "Fill", UDim2.fromScale(0, 0), UDim2.fromScale(0, 1), WHITE, 1, 2, "ui")
        new("UICorner", {CornerRadius = UDim.new(1, 0)}, fill)
        local fillGradient = gradient(fill, colors({C.blue, C.violet, C.magenta, C.cyan}))
        local barHalo = glow(progress, "BarHalo", UDim2.fromOffset(0, 34.5), UDim2.fromOffset(80, 24), C.violet, 0.65, 2)
        barHalo.AnchorPoint = Vector2.new(0, 0.5)
        local tip, tipScale = flare(progress, C.cyan, 10, 4)
        local hint = new("TextLabel", {
            Name = "TapHint", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 55),
            Size = UDim2.new(1, 0, 0, 23), Font = Enum.Font.GothamMedium,
            Text = Input.TouchEnabled and "Tap anywhere to continue" or "Click anywhere to continue",
            TextSize = 12, TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3,
        }, progress)
        fade(hint, "TextTransparency", 0.85, "hint")
        local input = new("TextButton", {
            Name = "ClickAnywhere", BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
            Size = UDim2.fromScale(1, 1), Active = true, Selectable = false, ZIndex = 50,
        }, root)
        S.connections[#S.connections + 1] = input.Activated:Connect(function()
            if S.alive and not S.dismissAt then S.tapped = true end
        end)

        local L = {w = 1280, h = 720, logoX = 940, logoY = 310, logoW = 620, photoX = 360, photoY = 360}
        local function layout()
            if not S.alive then return end
            local size = root.AbsoluteSize
            if size.X < 1 or size.Y < 1 then
                local cam = workspace.CurrentCamera
                size = cam and cam.ViewportSize or Vector2.new(1280, 720)
            end
            local w, h = size.X, size.Y
            local portrait = w / h < 1.15
            local margin = math.clamp(math.min(w, h) * 0.03, 12, 25)
            local photoH = portrait and math.min(h * 0.62, w * 1.02) or h * 1.035
            local photoW = photoH * (1536 / 864)
            L.w, L.h, L.photoX, L.photoY = w, h, w * 0.285, h * (portrait and 0.43 or 0.5)
            photo.Size = UDim2.fromOffset(photoW, photoH)
            local feather = math.max(24, photoH * (portrait and 0.13 or 0.055))
            topVeil.Position, topVeil.Size = UDim2.fromOffset(0, L.photoY - photoH * 0.5 - 16), UDim2.fromOffset(w, feather + 16)
            bottomVeil.Position, bottomVeil.Size = UDim2.fromOffset(0, L.photoY + photoH * 0.5 - feather), UDim2.fromOffset(w, feather + 16)
            L.logoW = math.min(w * (portrait and 0.53 or 0.455), h * 1.02, 860)
            L.logoX = math.min(w * 0.75, w - margin - L.logoW * 0.5 - 8)
            L.logoY = h * 0.435
            logoShade.multiplier = portrait and 1 or 0.3
            local logoH = L.logoW * (941 / 1672)
            logoGroup.Size = UDim2.fromOffset(L.logoW, logoH)
            local progressW = portrait and math.min(w - 2 * margin - 24, 350) or math.min(L.logoW * 0.82, 500)
            local progressY = portrait and (L.photoY + photoH * 0.5 + 24) or math.max(h * 0.72, L.logoY + logoH * 0.5 + 21)
            progressY = math.min(progressY, h - margin - 86)
            progress.Position, progress.Size = UDim2.fromOffset(portrait and w * 0.5 or L.logoX, progressY), UDim2.fromOffset(progressW, 82)
            status.TextSize = math.clamp(w / 110, 12, 15)
            percentage.TextSize = math.clamp(w / 88, 15, 20)
            hint.TextSize = math.clamp(w / 125, 11, 13)
            border.Position, border.Size = UDim2.fromOffset(margin, margin), UDim2.new(1, -2 * margin, 1, -2 * margin)
            local bw, bh = w - margin * 2, h - margin * 2
            corners[1].Position, corners[1].Rotation = UDim2.fromOffset(0, 0), 0
            corners[2].Position, corners[2].Rotation = UDim2.fromOffset(bw - 36, 0), 90
            corners[3].Position, corners[3].Rotation = UDim2.fromOffset(bw - 36, bh - 36), 180
            corners[4].Position, corners[4].Rotation = UDim2.fromOffset(0, bh - 36), 270
        end
        S.connections[#S.connections + 1] = root:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
        layout()

        local lastNumber, lastTint = -1, -1
        local fadeIn = math.max(0.1, CONFIG.FadeIn)
        local duration = math.max(0.1, CONFIG.LoadDuration)
        local fadeOut = math.max(0.1, CONFIG.FadeOut)
        local hold = math.max(0, CONFIG.CompletedHold)
        local function update(dt)
            if not S.alive then return end
            -- Progress is driven only by frame time. No image/network gate.
            S.elapsed = S.elapsed + math.max(0, dt or 0)
            local t = S.elapsed
            local p = math.clamp(t / duration, 0, 1)
            if p >= 1 and not S.completionAt then
                S.completionAt = t
                status.Text, status.TextColor3 = "Loading completed", C.white
            end
            if S.tapped and S.completionAt and t - S.completionAt >= hold and not S.dismissAt then S.dismissAt = t end
            local out = S.dismissAt and smooth((t - S.dismissAt) / fadeOut) or 0
            local alpha = smooth(t / fadeIn) * (1 - out)
            local logoAlpha = S.logoAt and smooth((t - S.logoAt) / 0.7) or 0
            local channels = {
                back = alpha, fx = alpha, ui = alpha * smooth(t / 0.85),
                photo = alpha * (S.backgroundAt and smooth((t - S.backgroundAt) / 0.9) or 0),
                logo = alpha * logoAlpha,
                glow = alpha * (S.glowAt and smooth((t - S.glowAt) / 0.8) or 0),
                hint = alpha * (S.completionAt and smooth((t - S.completionAt - hold) / 0.65) or 0),
            }
            root.Position = UDim2.fromOffset(0, out * math.min(CONFIG.SlidePixels, L.h * 0.13))
            photo.Position = UDim2.fromOffset(L.photoX + math.sin(t * 0.27) * 2, L.photoY + math.sin(t * 0.33) * 2.5)
            photoScale.Scale = 1 + math.sin(t * 0.22) * 0.004
            local motion = math.clamp(L.logoW / 650, 0.45, 1.15)
            logoGroup.Position = UDim2.fromOffset(L.logoX + math.sin(t * 0.43) * 2.3 * motion, L.logoY + math.sin(t * 0.9) * 4.2 * motion)
            logoGroup.Rotation = math.sin(t * 0.36) * 0.38
            logoScale.Scale = 1 + math.sin(t * 0.72) * 0.005
            fallbackAlpha.multiplier = 1 - logoAlpha
            fallback.Visible = logoAlpha < 0.999
            auraScale.Scale = 1 + math.sin(t * 0.8) * 0.055
            auraAlpha.multiplier = 0.82 + math.sin(t * 0.72) * 0.18
            mistScale.Scale = 1 + math.sin(t * 0.36) * 0.055
            mistAlpha.multiplier = 0.88 + math.sin(t * 0.51) * 0.12
            cyanMist.Position = UDim2.fromScale(0.66 + math.sin(t * 0.2) * 0.012, 0.75 + math.sin(t * 0.33) * 0.016)
            pinkMist.Position = UDim2.fromScale(0.85 + math.sin(t * 0.18) * 0.014, 0.35 + math.sin(t * 0.24) * 0.02)

            local n = math.floor(p * 100 + 0.00001)
            if n ~= lastNumber then percentage.Text = tostring(n) .. "%"; lastNumber = n end
            fill.Size = UDim2.fromScale(p, 1)
            barHalo.Size = UDim2.new(p, 0, 0, 22)
            tip.Position, tip.Visible = UDim2.new(p, 0, 0, 34.5), p > 0.003
            tipScale.Scale = 0.83 + math.sin(t * 1.5) * 0.09
            fillGradient.Offset = Vector2.new(math.sin(t * 0.6) * 0.11, 0)
            for i, sc in ipairs(flares) do sc.Scale = 0.6 + 0.3 * math.sin(t * 1.1 + i * 1.7) ^ 2 end
            for _, mote in ipairs(motes) do
                local y = (mote.y - t * mote.speed) % 1
                mote.object.Position = UDim2.fromScale(mote.x + math.sin(t * 0.3 + mote.phase) * 0.012, y)
                mote.object.Rotation = 45 + math.sin(t * 0.4 + mote.phase) * 19
                mote.alpha.multiplier = math.sin(y * math.pi) ^ 2 * (0.2 + 0.6 * math.sin(t * 0.85 + mote.phase) ^ 2)
            end
            for i, streak in ipairs(streaks) do
                local phase = (t * 0.055 + i / 3) % 1
                streak.object.Position = UDim2.fromScale(0.56 + phase * 0.4, 0.2 + i * 0.18 - phase * 0.1)
                streak.alpha.multiplier = math.sin(phase * math.pi) ^ 4
            end
            local bs = border.AbsoluteSize
            local perimeter = 2 * (bs.X + bs.Y)
            if perimeter > 0 then
                for i, runner in ipairs(runners) do
                    local d = (t * 74 + (i - 1) * perimeter * 0.5) % perimeter
                    local x, y
                    if d < bs.X then x, y = d, 0
                    elseif d < bs.X + bs.Y then x, y = bs.X, d - bs.X
                    elseif d < bs.X * 2 + bs.Y then x, y = bs.X * 2 + bs.Y - d, bs.Y
                    else x, y = 0, perimeter - d end
                    runner.object.Position = UDim2.fromOffset(x, y)
                    runner.scale.Scale = 0.8 + math.sin(t * 0.75 + i) * 0.12
                end
            end
            for _, g in ipairs(borderGradients) do g.Rotation = 25 + t * 11 end
            if t - lastTint >= 1 / 30 then
                lastTint = t
                local c1, c2, c3 = cycle(t / 17), cycle(t / 17 + 0.23), cycle(t / 17 + 0.48)
                local flow = colors({c1, c2, c3})
                for _, g in ipairs(borderGradients) do g.Color = flow end
                for i, edge in ipairs(edges) do
                    edge.object.BackgroundColor3 = cycle(t / 17 + i * 0.16)
                    edge.alpha.multiplier = 0.82 + math.sin(t * 0.65 + i) * 0.18
                end
                for i, line in ipairs(cornerLines) do line.BackgroundColor3 = cycle(t / 17 + math.floor((i - 1) / 2) * 0.23) end
                logoAura.ImageColor3 = cycle(t / 23 + 0.36)
                barHalo.ImageColor3 = c2
            end
            for _, entry in ipairs(S.fades) do
                local value = math.clamp(1 - entry.opacity * entry.multiplier * channels[entry.channel], 0, 1)
                if math.abs(value - entry.last) > 0.0004 then
                    entry.object[entry.property], entry.last = value, value
                end
            end
            if S.dismissAt and t - S.dismissAt >= fadeOut then cleanup(true) end
        end

        update(0)
        S.connections[#S.connections + 1] = RunService.RenderStepped:Connect(function(dt)
            local success, err = pcall(update, dt)
            if not success then warn("HzReyzn loading: " .. tostring(err)); cleanup(false) end
        end)

        -- These tasks never control progress. ImageTransparency starts changing
        -- as soon as a URI is assigned; nothing waits on a hidden IsLoaded flag.
        spawn(function()
            local uri = contentId(CONFIG.BackgroundAssetId) or loadLocalAsset(ASSETS.background, function() return S.alive end)
            if uri and S.alive then photo.Image = uri; S.backgroundAt = S.elapsed end
        end)
        spawn(function()
            local uri = contentId(CONFIG.LogoAssetId) or loadLocalAsset(ASSETS.logo, function() return S.alive end)
            if uri and S.alive then logo.Image = uri; S.logoAt = S.elapsed end
        end)
        spawn(function()
            local uri = contentId(CONFIG.GlowAssetId) or loadLocalAsset(ASSETS.glow, function() return S.alive end)
            if uri and S.alive then
                for _, object in ipairs(S.glowImages) do object.Image = uri end
                S.glowAt = S.elapsed
            end
        end)
        while S.alive do task.wait() end
    end, debug.traceback)
    if not ok then
        if S.alive then warn("HzReyzn loading: " .. tostring(problem)) end
        cleanup(false)
    end
    if S.completed and type(CONFIG.OnComplete) == "function" then
        local success, err = pcall(CONFIG.OnComplete)
        if not success then warn("HzReyzn OnComplete: " .. tostring(err)) end
    end
end

play()
