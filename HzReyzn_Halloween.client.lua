-- HzReyzn Halloween video intro. Original soundtrack, one playback, automatic exit.
-- Requires local asset support (getcustomasset/getsynasset and writefile).
-- Shared source embedded in Hub and the standalone intro; no extra module download.
local function createHalloweenMedia(isAlive)
    local base = "https://raw.githubusercontent.com/hzReyzn/scriptshz/main/assets/halloween/"
    local specs = {
        background = {file="cemetery-background-v1.jpg", bytes=267109, signature="\255\216\255"},
        logo = {file="hz-logo-v1.jpg", bytes=514147, signature="\255\216\255"},
        video = {file="intro-v1.webm", bytes=4176555, signature="\26\69\223\163"},
        videoFallback = {file="intro-v1.mp4", bytes=7042195, signature="ftyp", offset=5},
    }
    local resolved = {}
    local function valid(bytes, spec)
        local start = spec.offset or 1
        return type(bytes)=="string" and #bytes==spec.bytes
            and bytes:sub(start,start+#spec.signature-1)==spec.signature
    end
    return function(key)
        if not isAlive() then return "" end
        if resolved[key] then return resolved[key] end
        local spec = specs[key]
        local register = getcustomasset or getsynasset
        if not spec or type(register)~="function" or type(writefile)~="function" then return "" end
        local path = "HzReyzn_"..spec.file
        local exists = false
        if type(isfile)=="function" then
            local ok, found = pcall(isfile,path)
            exists = ok and found==true
        end
        if exists and type(readfile)=="function" then
            local ok, bytes = pcall(readfile,path)
            exists = ok and valid(bytes,spec)
        end
        if not exists then
            -- Bound the wait; a late HTTP response cannot write after cancellation.
            local pending, body, failed = true, nil, false
            task.spawn(function()
                local ok, data = pcall(function() return game:HttpGet(base..spec.file) end)
                if not pending or not isAlive() then return end
                if ok and valid(data,spec) then body=data else failed=true end
                pending=false
            end)
            local deadline=os.clock()+18
            while pending and isAlive() and os.clock()<deadline do task.wait(.05) end
            pending=false
            if failed or not body or not isAlive() then return "" end
            local ok=pcall(writefile,path,body)
            if not ok then return "" end
        end
        if not isAlive() then return "" end
        local ok, uri=pcall(register,path)
        if ok and type(uri)=="string" and uri~="" then resolved[key]=uri;return uri end
        return ""
    end
end

local options = ...
if type(options)~="table" then options={} end
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local parent=Players.LocalPlayer:WaitForChild("PlayerGui")
local owner=options.Owner
if owner and not owner.Parent then return "cancelled" end
local previous=parent:FindFirstChild("HzReyznHalloweenLoading")
if previous then previous:Destroy() end

local alive, result = true, "completed"
local screen, video, canvas, curtain
local links={}
local function connect(signal, callback)
    local link=signal:Connect(callback);links[#links+1]=link;return link
end
local function create(class, host, props)
    local object=Instance.new(class)
    for key,value in pairs(props) do object[key]=value end
    object.Parent=host
    return object
end
local function cleanup(cancelled)
    if not alive then return end
    alive=false
    if cancelled then result="cancelled" end
    for _,link in ipairs(links) do link:Disconnect() end
    table.clear(links)
    if video then
        pcall(function() video.Volume=0;video:Pause();video.Video="" end)
    end
    if screen and screen.Parent then screen:Destroy() end
end
local function isAlive()
    return alive and screen and screen.Parent~=nil and (not owner or owner.Parent~=nil)
end
local resolve=createHalloweenMedia(isAlive)
local function smooth(value)
    local t=math.clamp(value,0,1)
    return t*t*(3-2*t)
end
local function fadeCurtain(target,duration)
    local start=os.clock()
    local initial=curtain.BackgroundTransparency
    while isAlive() and os.clock()-start<duration do
        curtain.BackgroundTransparency=initial+(target-initial)*smooth((os.clock()-start)/duration)
        RunService.Heartbeat:Wait()
    end
    if isAlive() then curtain.BackgroundTransparency=target end
end
local function run()
    screen=create("ScreenGui",parent,{Name="HzReyznHalloweenLoading",ResetOnSpawn=false,
        IgnoreGuiInset=true,DisplayOrder=100000,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
    pcall(function() screen.ScreenInsets=Enum.ScreenInsets.None end)
    connect(screen.Destroying,function() cleanup(true) end)
    if owner then connect(owner.Destroying,function() cleanup(true) end) end
    -- Keep VideoFrame out of CanvasGroup render targets. Some clients cannot
    -- render/decode that combination even though the script has no Lua errors.
    canvas=create("Frame",screen,{Name="VideoStage",Size=UDim2.fromScale(1,1),
        BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=1,BorderSizePixel=0})
    video=create("VideoFrame",canvas,{Name="HalloweenVideo",AnchorPoint=Vector2.new(.5,.5),
        Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(1,1),BackgroundTransparency=1,
        BorderSizePixel=0,Video="",Looped=false,Volume=0,Playing=false,Visible=false})
    curtain=create("Frame",screen,{Name="VideoCurtain",Size=UDim2.fromScale(1,1),
        BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=2})
    -- Fit the complete 16:9 artwork on phones and desktops without cropping text.
    local function resize()
        local bounds=canvas.AbsoluteSize
        local height=math.min(bounds.Y,bounds.X*9/16)
        video.Size=UDim2.fromOffset(height*16/9,height)
    end
    connect(canvas:GetPropertyChangedSignal("AbsoluteSize"),resize);resize()
    create("TextButton",screen,{Name="InputShield",Size=UDim2.fromScale(1,1),Text="",
        BackgroundTransparency=1,AutoButtonColor=false,Active=true,ZIndex=3})

    local ended=false
    connect(video.Ended,function() ended=true end)
    local playing=false
    -- WEBM first; MP4 is tried only if the client's decoder cannot start WEBM.
    for _,key in ipairs({"video","videoFallback"}) do
        local uri=resolve(key)
        if not isAlive() then return end
        if uri~="" then
            fadeCurtain(0,.25)
            if not isAlive() then return end
            canvas.BackgroundTransparency=0;video.Visible=true
            video.Video=uri;video.TimePosition=0;ended=false
            -- Start immediately and observe actual playback. IsLoaded is not a
            -- reliable gate for every custom-asset provider.
            video:Play()
            task.spawn(function()
                if isAlive() then pcall(function() game:GetService("ContentProvider"):PreloadAsync({video}) end) end
            end)
            local deadline=os.clock()+10
            while isAlive() and video.TimePosition<.001 and not ended and os.clock()<deadline do task.wait(.03) end
            if not isAlive() then return end
            playing=video.TimePosition>=.001 or ended
            if playing then break end
            video:Pause();video.Video="";video.Visible=false
        end
    end
    if not playing then
        result="unavailable"
        warn("[HzReyzn] This client could not play the Halloween video; opening the Hub.")
        return
    end

    local started=os.clock()
    local lastPosition, lastAdvance=video.TimePosition,os.clock()
    local opacity=0
    local finishStarted
    while isAlive() do
        local now=os.clock()
        local position=video.TimePosition
        local duration=video.TimeLength>0 and video.TimeLength or 18.35
        if position>lastPosition+.001 then lastAdvance=now;lastPosition=position end
        local remaining=math.max(0,duration-position)
        -- Animate using playback time, so buffering never runs the fade ahead of the video.
        local fadeIn=smooth((now-started)/.7)
        local fadeOut=smooth(remaining/.95)
        if ended then
            finishStarted=finishStarted or now
            fadeOut=math.min(fadeOut,1-smooth((now-finishStarted)/.3))
        end
        opacity=math.min(fadeIn,fadeOut)
        curtain.BackgroundTransparency=opacity
        video.Volume=opacity -- original video's soundtrack; no second audio track
        if ended and (opacity<.002 or now-finishStarted>=.3) then break end
        if remaining<=.015 then break end
        if now-lastAdvance>6 or now-started>90 then
            result="unavailable"
            warn("[HzReyzn] Video playback stalled; opening the Hub.")
            break
        end
        RunService.Heartbeat:Wait()
    end
    -- Fade a stalled frame as well, instead of leaving a black or frozen loading screen.
    if isAlive() and opacity>.002 then
        local start=os.clock()
        while isAlive() and os.clock()-start<.35 do
            local value=opacity*(1-smooth((os.clock()-start)/.35))
            curtain.BackgroundTransparency=value;video.Volume=value
            RunService.Heartbeat:Wait()
        end
    end
end

local ok,err=xpcall(run,function(message) return tostring(message) end)
if not ok then result="unavailable";warn("[HzReyzn] Video intro: "..err) end
if isAlive() and curtain then
    -- The last movie frame fades into black; black then fades back into the game.
    if video then video.Volume=0;video:Pause();video.Visible=false;video.Video="" end
    if canvas then canvas.BackgroundTransparency=1 end
    fadeCurtain(1,.35)
end
cleanup(false)
return result
