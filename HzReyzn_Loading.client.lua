--[[
    HzReyzn Hub | Cinematic loading screen

    1 second fade-in. 5 second loading sequence (minimum).
    At 100%: "Loading completed", visible for at least 2 seconds.
    Click/tap anywhere to dismiss with a slow downward fade.
    An early click is remembered; the completion message still gets 2 seconds.
    Without a click the screen stays open and the background keeps looping.

    The logo is a real transparent PNG. No opaque JPEG or black logo plate.
    Images and videos are versioned public assets in this same repository.
    No embedded multi-megabyte strings; loading and caching run asynchronously.

    Environments with getcustomasset/writefile: no IDs are needed.
    Standard Roblox Studio: upload the PNG/video and set LogoAssetId,
    VideoAssetId and optionally PosterAssetId. Put this in a LocalScript.
    Cold-cache fix: visible render probes warm up the PNG and VideoFrame.
    Neither asset waits for IsLoaded while completely hidden.
    The main background preserves the source's 60 FPS (VP9 / H.264).
    VP8 at 30 FPS is a lighter compatibility fallback.
    If the client cannot decode any video, the poster/effects stay visible.
    Loading measures this intro's assets and minimum time, not the whole game.

    All instances, events, tasks and video playback are cleaned up on dismissal.
    Only this screen is modified. No Lighting, character or camera changes.
]]

local CONFIG = {
    FadeIn = 1,
    LoadDuration = 5,
    CompletedHold = 2,
    FadeOut = 1.35,
    SlidePixels = 64,
    LogoAssetId = "",
    VideoAssetId = "",
    PosterAssetId = "",
    Quality = "Auto", -- "Auto", "High", "Low"
    AssetTimeout = 30,
    VideoStartTimeout = 7,
    VideoVolume = 0,
    OnComplete = function()
        -- Open your main hub here, after the user dismisses the loading screen.
    end,
}

local ROOT = "https://raw.githubusercontent.com/hzReyzn/scriptshz/refs/heads/main/assets/loading/"
local ASSETS = {
    logo = {file = "hzreyzn-logo-v3.png", cache = "HzReyzn_Logo_v3.png", kind = "png", bytes = 1730191},
    poster = {file = "hzreyzn-background-poster-v3.jpg", cache = "HzReyzn_Poster_v3.jpg", kind = "jpg", bytes = 132818},
    vp9 = {file = "hzreyzn-background-v3-vp9.webm", cache = "HzReyzn_Background_v3_vp9.webm", kind = "webm", bytes = 7950998},
    vp8 = {file = "hzreyzn-background-v3-vp8.webm", cache = "HzReyzn_Background_v3_vp8.webm", kind = "webm", bytes = 4557281},
    mp4 = {file = "hzreyzn-background-v3.mp4", cache = "HzReyzn_Background_v3.mp4", kind = "mp4", bytes = 9417624},
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GUI_NAME = "HzReyzn_PrismLoading"
local PI2 = math.pi * 2
local C = {
    black = Color3.fromRGB(0, 0, 0),
    violet = Color3.fromRGB(139, 64, 255),
    deep = Color3.fromRGB(56, 17, 132),
    magenta = Color3.fromRGB(252, 61, 231),
    cyan = Color3.fromRGB(59, 220, 255),
    white = Color3.fromRGB(237, 241, 255),
    muted = Color3.fromRGB(182, 169, 212),
}

local function smooth(x)
    x = math.clamp(x, 0, 1)
    return x * x * (3 - 2 * x)
end

local function new(class, props, parent)
    local object = Instance.new(class)
    for key, value in pairs(props) do object[key] = value end
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

local FLOW = colors({C.cyan, C.violet, C.magenta, C.cyan})
local WHITE = Color3.fromRGB(255, 255, 255)
local SOFT = numbers({{0, 1}, {0.18, 0.8}, {0.5, 0}, {0.82, 0.8}, {1, 1}})
local INWARD = numbers({{0, 0}, {0.18, 0.45}, {0.5, 0.87}, {1, 1}})

local function assetId(value)
    value = tostring(value or "")
    if value == "" or value == "0" then return nil end
    return value:match("^%d+$") and ("rbxassetid://" .. value) or value
end

local function validBytes(bytes, kind)
    if type(bytes) ~= "string" or #bytes < 64 then return false end
    if kind == "png" then return bytes:sub(1, 8) == "\137PNG\13\10\26\10" end
    if kind == "jpg" then return bytes:sub(1, 2) == "\255\216" end
    if kind == "webm" then return bytes:sub(1, 4) == "\26\69\223\163" end
    if kind == "mp4" then return bytes:sub(5, 8) == "ftyp" end
    return false
end

local function play()
    if not RunService:IsClient() then warn("HzReyzn: run this as a client LocalScript."); return end
    local player = Players.LocalPlayer
    if not player then return end
    local playerGui = player:WaitForChild("PlayerGui", 10)
    if not playerGui then return end

    local previous = playerGui:FindFirstChild(GUI_NAME)
    if previous then
        local stop = previous:FindFirstChild("StopLoading")
        if stop and stop:IsA("BindableEvent") then stop:Fire() end
        if previous.Parent then previous:Destroy() end
    end

    local S = {
        alive = true, completed = false, fades = {}, connections = {}, tasks = {},
        started = os.clock(), logoDone = false, videoDone = false,
        clicked = false, completionAt = nil, dismissAt = nil,
        mediaAt = nil, logoAt = nil, videoAt = nil, video = nil, view = Vector2.new(1280, 720),
    }
    local gui = new("ScreenGui", {
        Name = GUI_NAME, IgnoreGuiInset = true, ResetOnSpawn = false,
        DisplayOrder = 10000, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, playerGui)
    pcall(function() gui.ScreenInsets = Enum.ScreenInsets.None; gui.ClipToDeviceSafeArea = false end)

    local function cleanup(completed)
        if not S.alive then return end
        S.alive, S.completed = false, completed == true
        for _, connection in ipairs(S.connections) do connection:Disconnect() end
        if S.video then
            pcall(function() S.video:Pause(); S.video.Video = "" end)
        end
        for _, thread in ipairs(S.tasks) do
            if type(task.cancel) == "function" then pcall(task.cancel, thread) end
        end
        gui:Destroy()
        table.clear(S.connections)
        table.clear(S.tasks)
        table.clear(S.fades)
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

    local function frame(parent, name, pos, size, color, opacity, z, channel)
        local f = new("Frame", {
            Name = name, Position = pos, Size = size, BackgroundColor3 = color or C.black,
            BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = z or 1,
        }, parent)
        if opacity and opacity > 0 then fade(f, "BackgroundTransparency", opacity, channel) end
        return f
    end

    local function gradient(object, color, alpha, angle)
        return new("UIGradient", {Color = color or FLOW, Transparency = alpha or NumberSequence.new(0), Rotation = angle or 0}, object)
    end

    local function stroke(object, color, thickness, opacity)
        local st = new("UIStroke", {Color = color, Thickness = thickness, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, object)
        fade(st, "Transparency", opacity)
        return st
    end

    local function light(parent, name, width, height, color, opacity, z)
        local f = frame(parent, name, UDim2.fromOffset(0, 0), UDim2.fromOffset(width, height), color, opacity, z)
        f.AnchorPoint = Vector2.new(0.5, 0.5)
        gradient(f, ColorSequence.new(WHITE), SOFT)
        return f
    end

    local function glow(parent, name, width, height, color, strength, layers, z)
        local group = frame(parent, name, UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(width, height), C.black, 0, z)
        group.AnchorPoint = Vector2.new(0.5, 0.5)
        for i = 1, layers do
            local k = 1 - (i - 1) / layers * 0.91
            local disk = frame(group, "SoftGlow", UDim2.fromScale(0.5, 0.5), UDim2.fromScale(k, k), color,
                strength * (0.2 + 0.8 * (i / layers) ^ 2), 1)
            disk.AnchorPoint = Vector2.new(0.5, 0.5)
            new("UICorner", {CornerRadius = UDim.new(0.5, 0)}, disk)
        end
        return group
    end

    local function star(parent, color, size, z)
        local group = frame(parent, "LensFlare", UDim2.fromOffset(0, 0), UDim2.fromOffset(1, 1), C.black, 0, z)
        light(group, "HaloH", size * 2, 4, color, 0.38, 1)
        light(group, "CoreH", size * 2, 1.2, C.white, 0.82, 2)
        local haloV = light(group, "HaloV", size * 1.3, 4, color, 0.28, 1); haloV.Rotation = 90
        local coreV = light(group, "CoreV", size * 1.3, 1.2, C.white, 0.8, 2); coreV.Rotation = 90
        return group, new("UIScale", {Scale = 1}, group)
    end

    local function spawnTask(fn)
        local thread = task.spawn(function()
            local ok, why = pcall(fn)
            if not ok and S.alive then warn("HzReyzn asset: " .. tostring(why)) end
        end)
        S.tasks[#S.tasks + 1] = thread
    end

    local function localAsset(asset)
        local getAsset = getcustomasset or getsynasset
        if type(getAsset) ~= "function" or type(writefile) ~= "function" then return nil end
        local function valid(bytes)
            return validBytes(bytes, asset.kind) and (not asset.bytes or #bytes == asset.bytes)
        end
        if type(isfile) == "function" then
            local ok, exists = pcall(isfile, asset.cache)
            if ok and exists then
                local cacheValid = false
                if type(readfile) == "function" then
                    local readOK, bytes = pcall(readfile, asset.cache)
                    cacheValid = readOK and valid(bytes)
                end
                if cacheValid then
                    local assetOK, uri = pcall(getAsset, asset.cache)
                    if assetOK and type(uri) == "string" and uri ~= "" then return uri end
                end
            end
        end
        local ok, bytes = pcall(function() return game:HttpGet(ROOT .. asset.file) end)
        if not S.alive then return nil end
        if not ok or not valid(bytes) then
            warn("HzReyzn: incomplete or failed download: " .. asset.file)
            return nil
        end
        local written, uri = pcall(function()
            writefile(asset.cache, bytes)
            return getAsset(asset.cache)
        end)
        if not S.alive then return nil end
        return written and type(uri) == "string" and uri ~= "" and uri or nil
    end

    local function waitLoaded(object, timeout)
        local untilTime = os.clock() + timeout
        while S.alive and object.Parent and os.clock() < untilTime do
            if object.IsLoaded then return true end
            task.wait()
        end
        return false
    end

    local function warmImage(uri, timeout)
        -- A transparent/hidden label may never enter Roblox's render queue.
        -- This tiny on-screen probe is outside the fading CanvasGroup.
        local probe = new("ImageLabel", {
            Name = "ImageWarmup", Image = uri, ImageTransparency = 0,
            BackgroundTransparency = 1, BorderSizePixel = 0,
            Position = UDim2.fromOffset(2, 2), Size = UDim2.fromOffset(2, 2),
            Visible = true, ZIndex = 100,
        }, gui)
        local ok, loaded = pcall(waitLoaded, probe, timeout)
        if probe.Parent then probe:Destroy() end
        return ok and loaded and S.alive
    end

    local ok, why = xpcall(function()
        local low = CONFIG.Quality == "Low" or (CONFIG.Quality == "Auto" and UserInputService.TouchEnabled)
        local random = Random.new(4927)
        local root = frame(gui, "Scene", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), C.black, 1, 1, "back")
        root.ClipsDescendants = true

        -- Only the video is composited through CanvasGroup. The logo/text stay
        -- in regular GUI layers, preserving their sharpness on small screens.
        local media = new("CanvasGroup", {
            Name = "VideoFade", BackgroundTransparency = 1, BorderSizePixel = 0,
            Position = UDim2.fromOffset(0, 0), Size = UDim2.fromScale(1, 1),
            GroupTransparency = 1, ZIndex = 1,
        }, root)
        gradient(media, ColorSequence.new(WHITE), numbers({{0, 0.16}, {0.15, 0}, {0.62, 0}, {0.84, 0.47}, {1, 1}}))
        local poster = new("ImageLabel", {
            Name = "VideoPoster", BackgroundTransparency = 1, ImageTransparency = 0,
            Size = UDim2.fromScale(1, 1), ScaleType = Enum.ScaleType.Stretch, ZIndex = 3,
        }, media)
        local video = new("VideoFrame", {
            Name = "LoopingBackground", BackgroundTransparency = 1, BorderSizePixel = 0,
            Position = UDim2.fromOffset(2, 2), Size = UDim2.fromOffset(2, 2),
            Looped = true, Playing = false,
            Volume = math.clamp(CONFIG.VideoVolume, 0, 1), Visible = true, ZIndex = 100,
        }, gui)
        S.video = video

        local atmosphere = frame(root, "Atmosphere", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), C.black, 0, 2)
        local topVeil = frame(atmosphere, "TopFeather", UDim2.fromOffset(0, 0), UDim2.fromOffset(1, 1), C.black, 1, 1, "back")
        gradient(topVeil, ColorSequence.new(WHITE), NumberSequence.new(0, 1), 90)
        local bottomVeil = frame(atmosphere, "BottomFeather", UDim2.fromOffset(0, 0), UDim2.fromOffset(1, 1), C.black, 1, 1, "back")
        gradient(bottomVeil, ColorSequence.new(WHITE), NumberSequence.new(0, 1), 270)
        local mist = glow(atmosphere, "VioletMist", 700, 300, C.violet, 0.025, low and 12 or 19, 2)
        local mistScale = new("UIScale", {Scale = 1}, mist)
        local mistCyan = glow(atmosphere, "CyanMist", 460, 170, C.cyan, 0.019, low and 10 or 16, 2)
        local mistMagenta = glow(atmosphere, "MagentaMist", 550, 200, C.magenta, 0.022, low and 12 or 18, 2)

        local motes = {}
        for i = 1, low and 20 or 34 do
            local size = random:NextNumber(1, 2.8)
            local color = ({C.cyan, C.violet, C.magenta, C.white})[i % 4 + 1]
            local p = frame(atmosphere, "LightMote", UDim2.fromScale(0, 0), UDim2.fromOffset(size, size), color, 0, 3)
            p.AnchorPoint, p.Rotation = Vector2.new(0.5, 0.5), 45
            motes[i] = {object = p, alpha = fade(p, "BackgroundTransparency", 0.72),
                x = random:NextNumber(0.08, 0.95), y = random:NextNumber(0.12, 0.91),
                phase = random:NextNumber(0, PI2), speed = random:NextNumber(0.010, 0.024)}
        end

        local frameLayer = frame(root, "FrameLayer", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), C.black, 0, 4)
        local border = frame(frameLayer, "LuminousFrame", UDim2.fromOffset(18, 18), UDim2.new(1, -36, 1, -36), C.black, 0, 1)
        local edgeStroke = stroke(border, C.white, 1.2, 0.62)
        local borderGradient = gradient(edgeStroke, FLOW)
        local edges = {}
        local defs = {
            {UDim2.fromScale(0, 0), UDim2.fromScale(0.11, 1), 0, C.violet},
            {UDim2.fromScale(0.89, 0), UDim2.fromScale(0.11, 1), 180, C.magenta},
            {UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.10), 90, C.violet},
            {UDim2.fromScale(0, 0.90), UDim2.fromScale(1, 0.10), 270, C.violet},
        }
        for i, def in ipairs(defs) do
            local edge = frame(border, "InwardGlow", def[1], def[2], def[4], 0, 1)
            edges[i] = fade(edge, "BackgroundTransparency", 0.22)
            gradient(edge, ColorSequence.new(WHITE), INWARD, def[3])
        end
        local corners, runners = {}, {}
        for i = 1, 4 do
            local g = frame(border, "Corner", UDim2.fromOffset(0, 0), UDim2.fromOffset(58, 58), C.black, 0, 2)
            local tint = i % 2 == 0 and C.cyan or C.magenta
            frame(g, "Horizontal", UDim2.fromOffset(0, 0), UDim2.fromOffset(58, 2), tint, 0.85, 1)
            frame(g, "Vertical", UDim2.fromOffset(0, 0), UDim2.fromOffset(2, 58), tint, 0.85, 1)
            frame(g, "Detail", UDim2.fromOffset(7, 7), UDim2.fromOffset(21, 1), C.white, 0.34, 1)
            corners[i] = g
        end
        for i = 1, 2 do
            local group, scale = star(border, i == 1 and C.cyan or C.magenta, 20, 3)
            runners[i] = {object = group, scale = scale}
        end

        -- The provided replacement artwork, composited with real PNG alpha.
        local logoGroup = frame(root, "FloatingLogo", UDim2.fromScale(0.74, 0.43), UDim2.fromOffset(620, 349), C.black, 0, 6)
        logoGroup.AnchorPoint = Vector2.new(0.5, 0.5)
        local logoScale = new("UIScale", {Scale = 1}, logoGroup)
        local logoAura = glow(logoGroup, "LogoAura", 580, 126, C.violet, 0.031, low and 12 or 20, 1)
        logoAura.Position = UDim2.fromScale(0.5, 0.77)
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
        new("UITextSizeConstraint", {MinTextSize = 14, MaxTextSize = 64}, fallback)
        gradient(fallback, colors({C.cyan, C.white, C.magenta}))
        local fallbackAlpha = fade(fallback, "TextTransparency", 0.92)
        local logoFlares = {}
        for i, point in ipairs({{0.31, 0.43}, {0.80, 0.31}, {0.75, 0.66}}) do
            local g, sc = star(logoGroup, i % 2 == 0 and C.cyan or C.magenta, 17, 4)
            g.Position = UDim2.fromScale(point[1], point[2])
            logoFlares[i] = sc
        end

        local progress = frame(root, "Progress", UDim2.fromScale(0.74, 0.76), UDim2.fromOffset(370, 78), C.black, 0, 7)
        progress.AnchorPoint = Vector2.new(0.5, 0)
        local status = new("TextLabel", {
            Name = "CompletionLabel", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 0),
            Size = UDim2.new(1, -70, 0, 23), Font = Enum.Font.GothamMedium,
            Text = "Loading", TextSize = 14, TextColor3 = C.muted,
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2,
        }, progress)
        fade(status, "TextTransparency", 1, "ui")
        local percentage = new("TextLabel", {
            Name = "Percentage", BackgroundTransparency = 1, Position = UDim2.new(1, -68, 0, -1),
            Size = UDim2.fromOffset(68, 24), Font = Enum.Font.GothamMedium,
            Text = "0%", TextSize = 20, TextColor3 = C.white,
            TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 2,
        }, progress)
        fade(percentage, "TextTransparency", 1, "ui")
        local track = frame(progress, "Track", UDim2.fromOffset(0, 31), UDim2.new(1, 0, 0, 4), C.deep, 0.72, 2, "ui")
        new("UICorner", {CornerRadius = UDim.new(1, 0)}, track)
        stroke(track, C.violet, 1, 0.25)
        local fill = frame(track, "Fill", UDim2.fromScale(0, 0), UDim2.fromScale(0, 1), WHITE, 1, 2, "ui")
        new("UICorner", {CornerRadius = UDim.new(1, 0)}, fill)
        local fillGradient = gradient(fill, colors({C.deep, C.violet, C.magenta, C.cyan, C.white}))
        local barHalo = frame(progress, "BarHalo", UDim2.fromOffset(0, 28), UDim2.new(0, 0, 0, 10), C.violet, 0.14, 1, "ui")
        new("UICorner", {CornerRadius = UDim.new(1, 0)}, barHalo)
        local tip, tipScale = star(progress, C.cyan, 13, 3)
        local hint = new("TextLabel", {
            Name = "TapHint", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 53),
            Size = UDim2.new(1, 0, 0, 24), Font = Enum.Font.GothamMedium,
            Text = UserInputService.TouchEnabled and "Tap anywhere to continue" or "Click anywhere to continue",
            TextSize = 12, TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 2,
        }, progress)
        fade(hint, "TextTransparency", 0.9, "hint")
        local input = new("TextButton", {
            Name = "ClickAnywhere", BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
            Size = UDim2.fromScale(1, 1), Active = true, Selectable = false, ZIndex = 50,
        }, root)
        S.connections[#S.connections + 1] = input.Activated:Connect(function()
            if S.alive and not S.dismissAt then S.clicked = true end
        end)

        local layoutData = {logoX = 0, logoY = 0, logoW = 620, progressW = 370, margin = 18}
        local function layout()
            if not S.alive then return end
            local size = root.AbsoluteSize
            if size.X < 1 or size.Y < 1 then
                local cam = workspace.CurrentCamera
                size = cam and cam.ViewportSize or S.view
            end
            S.view = size
            local w, h = size.X, size.Y
            local portrait = w / h < 1.15
            local margin = math.clamp(math.min(w, h) * 0.03, 12, 24)
            local videoH = portrait and math.min(h * 0.62, w * 0.94) or h
            local videoW = videoH * (1280 / 672)
            local videoX = w * (portrait and 0.24 or 0.285) - videoW * 0.47
            local videoY = portrait and (h * 0.5 - videoH * 0.5) or 0
            media.Position, media.Size = UDim2.fromOffset(videoX, videoY), UDim2.fromOffset(videoW, videoH)
            local feather = math.max(24, videoH * (portrait and 0.15 or 0.07))
            topVeil.Position, topVeil.Size = UDim2.fromOffset(0, videoY), UDim2.fromOffset(w, feather)
            bottomVeil.Position, bottomVeil.Size = UDim2.fromOffset(0, videoY + videoH - feather), UDim2.fromOffset(w, feather)
            local logoW = math.min(w * (portrait and 0.52 or 0.48), h * 1.03, 1060)
            local logoX = math.min(w * 0.745, w - margin - logoW * 0.5 - 5)
            local logoY = portrait and h * 0.48 or h * 0.435
            local logoH = logoW * (941 / 1672)
            logoGroup.Size = UDim2.fromOffset(logoW, logoH)
            logoAura.Size = UDim2.fromOffset(logoW * 0.94, logoH * 0.44)
            local progressW = portrait and math.min(w - margin * 2 - 38, 340) or math.min(logoW * 0.80, 470)
            local progressY = portrait and (videoY + videoH + 18) or math.max(h * 0.755, logoY + logoH * 0.5 + 24)
            local progressX = portrait and w * 0.5 or logoX
            progress.Position, progress.Size = UDim2.fromOffset(progressX, progressY), UDim2.fromOffset(progressW, 80)
            status.TextSize = math.clamp(w / 95, 12, 16)
            percentage.TextSize = math.clamp(w / 72, 16, 22)
            hint.TextSize = math.clamp(w / 110, 11, 13)
            layoutData.logoX, layoutData.logoY, layoutData.logoW = logoX, logoY, logoW
            layoutData.progressW, layoutData.margin = progressW, margin
            border.Position, border.Size = UDim2.fromOffset(margin, margin), UDim2.new(1, -2 * margin, 1, -2 * margin)
            local bw, bh = w - 2 * margin, h - 2 * margin
            corners[1].Position, corners[1].Rotation = UDim2.fromOffset(0, 0), 0
            corners[2].Position, corners[2].Rotation = UDim2.fromOffset(bw - 58, 0), 90
            corners[3].Position, corners[3].Rotation = UDim2.fromOffset(bw - 58, bh - 58), 180
            corners[4].Position, corners[4].Rotation = UDim2.fromOffset(0, bh - 58), 270
            mist.Position, mist.Size = UDim2.fromScale(0.76, 0.48), UDim2.fromOffset(w * 0.67, math.min(h * 0.72, 440))
            mistCyan.Position, mistCyan.Size = UDim2.fromScale(0.68, 0.74), UDim2.fromOffset(w * 0.52, h * 0.23)
            mistMagenta.Position, mistMagenta.Size = UDim2.fromScale(0.87, 0.31), UDim2.fromOffset(w * 0.49, h * 0.37)
        end
        S.connections[#S.connections + 1] = root:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
        layout()

        -- Begin drawing immediately, independently of downloads and video decoding.
        local lastEffects, lastPercent, shownProgress = -1, -1, 0
        local fadeIn = math.max(0.1, CONFIG.FadeIn)
        local duration = math.max(0.1, CONFIG.LoadDuration)
        local fadeOut = math.max(0.1, CONFIG.FadeOut)
        local completedHold = math.max(0, CONFIG.CompletedHold)
        local function update()
            if not S.alive then return end
            local now = os.clock()
            local t = now - S.started
            if t >= CONFIG.AssetTimeout then S.logoDone, S.videoDone = true, true end
            local ready = S.logoDone and S.videoDone
            local rawProgress = math.min(t / duration, ready and 1 or 0.96)
            shownProgress = math.max(shownProgress, rawProgress)
            if shownProgress >= 1 and not S.completionAt then
                S.completionAt = now
                status.Text, status.TextColor3 = "Loading completed", C.white
            end
            if S.clicked and S.completionAt and now - S.completionAt >= completedHold and not S.dismissAt then
                S.dismissAt = now
            end
            local out = S.dismissAt and smooth((now - S.dismissAt) / fadeOut) or 0
            local intro = smooth(t / fadeIn)
            local alpha = intro * (1 - out)
            local logoAlpha = S.logoAt and smooth((now - S.logoAt) / 0.45) or 0
            local hintAlpha = S.completionAt and smooth((now - S.completionAt - completedHold) / 0.6) or 0
            local channels = {
                back = alpha, fx = alpha * smooth(t / 0.8), ui = alpha * smooth(t / 0.75),
                logo = alpha * logoAlpha, hint = alpha * hintAlpha,
            }
            root.Position = UDim2.fromOffset(0, out * math.min(CONFIG.SlidePixels, S.view.Y * 0.13))
            media.GroupTransparency = 1 - alpha * (S.mediaAt and smooth((now - S.mediaAt) / 0.5) or 0)
            -- Keep the poster on top until actual playback advances, then
            -- crossfade it away instead of flashing an empty/black video.
            poster.ImageTransparency = S.videoAt and smooth((now - S.videoAt) / 0.45) or 0
            fallbackAlpha.multiplier = 1 - logoAlpha
            fallback.Visible = logoAlpha < 0.999
            local floatScale = math.clamp(layoutData.logoW / 600, 0.45, 1.4)
            logoGroup.Position = UDim2.fromOffset(layoutData.logoX + math.sin(t * 0.46) * 2.8 * floatScale,
                layoutData.logoY + math.sin(t * 1.15) * 5.2 * floatScale)
            logoGroup.Rotation = math.sin(t * 0.55) * 0.55
            logoScale.Scale = 1 + math.sin(t * 0.85) * 0.007
            auraScale.Scale = 1 + math.sin(t * 1.35) * 0.037
            local number = math.floor(shownProgress * 100 + 0.00001)
            if number ~= lastPercent then percentage.Text = tostring(number) .. "%"; lastPercent = number end
            fill.Size = UDim2.fromScale(shownProgress, 1)
            barHalo.Size = UDim2.new(shownProgress, 0, 0, 10)
            tip.Position = UDim2.new(shownProgress, 0, 0, 33)
            tip.Visible = shownProgress > 0.006
            tipScale.Scale = 0.84 + math.sin(t * 2.1) * 0.12

            if t - lastEffects >= (low and 1 / 30 or 1 / 60) then
                lastEffects = t
                borderGradient.Rotation = t * 10 + 20
                fillGradient.Offset = Vector2.new(math.sin(t * 0.7) * 0.08, 0)
                mistScale.Scale = 1 + math.sin(t * 0.55) * 0.05
                for i, entry in ipairs(edges) do entry.multiplier = 0.86 + 0.14 * math.sin(t * 1.1 + i) end
                for i, sc in ipairs(logoFlares) do sc.Scale = 0.63 + 0.3 * math.sin(t * 1.35 + i * 1.9) ^ 2 end
                for _, mote in ipairs(motes) do
                    local y = (mote.y - t * mote.speed) % 1
                    mote.object.Position = UDim2.fromScale(mote.x + math.sin(t * 0.35 + mote.phase) * 0.014, y)
                    mote.object.Rotation = 45 + math.sin(t * 0.6 + mote.phase) * 28
                    mote.alpha.multiplier = math.sin(y * math.pi) ^ 2 * (0.24 + 0.76 * math.sin(t * 1.4 + mote.phase) ^ 2)
                end
                local bs = border.AbsoluteSize
                local perimeter = 2 * (bs.X + bs.Y)
                if perimeter > 0 then
                    for i, runner in ipairs(runners) do
                        local d = (t * 90 + (i - 1) * perimeter * 0.5) % perimeter
                        local x, y
                        if d < bs.X then x, y = d, 0
                        elseif d < bs.X + bs.Y then x, y = bs.X, d - bs.X
                        elseif d < 2 * bs.X + bs.Y then x, y = 2 * bs.X + bs.Y - d, bs.Y
                        else x, y = 0, perimeter - d end
                        runner.object.Position = UDim2.fromOffset(x, y)
                    end
                end
            end
            for _, entry in ipairs(S.fades) do
                local transparency = 1 - entry.opacity * entry.multiplier * channels[entry.channel]
                if math.abs(transparency - entry.last) > 0.0005 then
                    entry.object[entry.property] = math.clamp(transparency, 0, 1)
                    entry.last = transparency
                end
            end
            if S.dismissAt and now - S.dismissAt >= fadeOut then cleanup(true) end
        end

        update()
        S.connections[#S.connections + 1] = RunService.RenderStepped:Connect(function()
            local success, problem = pcall(update)
            if not success then warn("HzReyzn loading: " .. tostring(problem)); cleanup(false) end
        end)

        spawnTask(function()
            local success = pcall(function()
                local uri = assetId(CONFIG.LogoAssetId) or localAsset(ASSETS.logo)
                if not uri or not S.alive then return end
                logo.Image = uri
                if warmImage(uri, 10) then S.logoAt = os.clock() end
            end)
            if S.alive then
                S.logoDone = true
                if not success or not S.logoAt then warn("HzReyzn: set LogoAssetId if this client cannot load local images.") end
            end
        end)
        spawnTask(function()
            local uri = assetId(CONFIG.PosterAssetId) or localAsset(ASSETS.poster)
            if not uri or not S.alive then return end
            poster.Image = uri
            if warmImage(uri, 8) then S.mediaAt = S.mediaAt or os.clock() end
        end)
        spawnTask(function()
            local loaded = false
            local function tryVideo(uri)
                if not uri or not S.alive then return false end
                -- Some clients throw for an unsupported URI instead of timing
                -- out. Isolate each format so MP4 is still tried after WebM.
                local accepted, result = pcall(function()
                    -- Decode visibly on-screen before putting the video in
                    -- the fading group. Visible=false caused a cold-start
                    -- deadlock on clients that defer invisible media loads.
                    video.Parent = gui
                    video.Position, video.Size = UDim2.fromOffset(2, 2), UDim2.fromOffset(2, 2)
                    video.Visible, video.ZIndex = true, 100
                    video.Playing, video.Video = false, ""
                    video.Video = uri
                    video.Looped = true
                    video:Play()
                    local untilTime = os.clock() + CONFIG.VideoStartTimeout
                    local previous, moving, restarted = video.TimePosition, 0, false
                    while S.alive and os.clock() < untilTime do
                        task.wait()
                        if not S.alive then return false end
                        if video.IsLoaded and not restarted then
                            video:Play()
                            restarted = true
                        end
                        local position = video.TimePosition
                        if position > previous then moving = moving + 1 end
                        previous = position
                        if moving >= 2 then break end
                    end
                    if not S.alive or moving < 2 then return false end
                    video.Position, video.Size = UDim2.fromScale(0, 0), UDim2.fromScale(1, 1)
                    video.ZIndex, video.Parent = 2, media
                    S.videoAt = os.clock()
                    S.mediaAt = S.mediaAt or os.clock()
                    return true
                end)
                return accepted and result == true
            end
            local success = pcall(function()
                local id = assetId(CONFIG.VideoAssetId)
                if id then loaded = tryVideo(id) end
                if not loaded and S.alive then loaded = tryVideo(localAsset(ASSETS.vp9)) end
                if not loaded and S.alive then loaded = tryVideo(localAsset(ASSETS.vp8)) end
                if not loaded and S.alive then loaded = tryVideo(localAsset(ASSETS.mp4)) end
            end)
            if S.alive then
                S.videoDone = true
                if not success or not loaded then
                    video.Visible, video.Playing, video.Video = false, false, ""
                    warn("HzReyzn: local video is unsupported; poster remains active. Set VideoAssetId for a Roblox video asset.")
                end
            end
        end)

        while S.alive do task.wait() end
    end, debug.traceback)

    if not ok then
        if S.alive then warn("HzReyzn loading: " .. tostring(why)) end
        cleanup(false)
    end
    if S.completed and type(CONFIG.OnComplete) == "function" then
        local success, problem = pcall(CONFIG.OnComplete)
        if not success then warn("HzReyzn OnComplete: " .. tostring(problem)) end
    end
end

play()
