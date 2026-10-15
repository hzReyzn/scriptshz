-- HzReyzn Halloween: compatible playback of the supplied movie at 24 fps.
-- Original frame order and soundtrack. No VideoFrame / CanvasGroup decoder dependency.
local Config = {packs={{file="frames-01.hzf",bytes=427202,first=1,count=12,lengths={27353,15516,28007,5386,30984,56176,60240,61974,15816,5708,58808,61178}},{file="frames-02.hzf",bytes=2596169,first=13,count=12,lengths={62447,158611,234532,236614,236379,238721,239251,239703,236139,237485,237544,238687}},{file="frames-03.hzf",bytes=2910135,first=25,count=12,lengths={236857,239503,242141,243208,243203,243083,243390,244525,242556,244258,243969,243386}},{file="frames-04.hzf",bytes=2888169,first=37,count=12,lengths={242844,242961,243015,242858,232173,236402,238856,240907,242012,241837,241960,242288}},{file="frames-05.hzf",bytes=2076711,first=49,count=12,lengths={240368,241234,241049,234928,235637,214236,176651,166154,144226,85013,55424,41735}},{file="frames-06.hzf",bytes=413376,first=61,count=12,lengths={42659,20597,15186,19634,19584,13472,36734,38671,34506,86394,42529,43354}},{file="frames-07.hzf",bytes=60055,first=73,count=2,lengths={44688,15351}}},audioBytes=323765,fps=24,frames=441,duration=18.35,width=512,height=288,perSheet=6,sheets=74}
local options=...
if type(options)~="table" then options={} end
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local ContentProvider=game:GetService("ContentProvider")
local parent=Players.LocalPlayer:WaitForChild("PlayerGui")
local owner=options.Owner
if owner and not owner.Parent then return "cancelled" end
local previous=parent:FindFirstChild("HzReyznHalloweenLoading")
if previous then previous:Destroy() end

local alive,result=true,"completed"
local screen,stage,sound
local showing
local links,slots,sheets={},{},{}
local base="https://raw.githubusercontent.com/hzReyzn/scriptshz/main/assets/halloween/sequence-v3/"
local register=type(getcustomasset)=="function" and getcustomasset or getsynasset
local audioUri,audioDone="",false
local nextPack,packErrors=1,{}
local function create(class,host,props)
    local object=Instance.new(class)
    for key,value in pairs(props) do object[key]=value end
    object.Parent=host
    return object
end
local function connect(signal,callback)
    local link=signal:Connect(callback);links[#links+1]=link;return link
end
local function isAlive()
    return alive and screen and screen.Parent~=nil and (not owner or owner.Parent~=nil)
end
local function status(value)
    if screen and screen.Parent then screen:SetAttribute("PlaybackStatus",value) end
    if owner and owner.Parent then owner:SetAttribute("IntroStatus",value) end
end
local function cleanup(cancelled)
    if not alive then return end
    if cancelled then result="cancelled" end
    alive=false
    for _,link in ipairs(links) do link:Disconnect() end
    table.clear(links)
    if sound then pcall(function() sound.Volume=0;sound:Stop();sound:Destroy() end) end
    for _,slot in ipairs(slots) do if slot.image.Parent then slot.image.Image="" end end
    if screen and screen.Parent then screen:Destroy() end
end
local function smooth(t)
    t=math.clamp(t,0,1);return t*t*(3-2*t)
end
local function cached(path,bytes,signature)
    if type(isfile)~="function" then return false end
    local ok,exists=pcall(isfile,path)
    if not ok or not exists then return false end
    if type(readfile)=="function" then
        local read,data=pcall(readfile,path)
        return read and type(data)=="string" and #data==bytes and data:sub(1,#signature)==signature
    end
    return true
end
local function download(file,bytes,signature)
    local waiting,data=true,nil
    task.spawn(function()
        local ok,body=pcall(function() return game:HttpGet(base..file) end)
        if not waiting or not isAlive() then return end
        if ok and type(body)=="string" and #body==bytes and body:sub(1,#signature)==signature then data=body end
        waiting=false
    end)
    local deadline=os.clock()+18
    while waiting and isAlive() and os.clock()<deadline do task.wait(.05) end
    waiting=false
    return isAlive() and data or nil
end
local function asset(path)
    if not isAlive() then return nil end
    local ok,uri=pcall(register,path)
    return ok and type(uri)=="string" and uri~="" and uri or nil
end
local function u32(data,offset)
    local a,b,c,d=string.byte(data,offset,offset+3)
    if not d then return nil end
    return a+b*256+c*65536+d*16777216
end
local function sheetPath(index)
    return string.format("HzReyzn_sequence_v3_%03d.jpg",index)
end
local function loadPack(index)
    local pack=Config.packs[index]
    local allCached=true
    for offset,length in ipairs(pack.lengths) do
        if not cached(sheetPath(pack.first+offset-1),length,"\255\216\255") then allCached=false;break end
    end
    if not allCached then
        local bytes=download(pack.file,pack.bytes,"HZF1")
        if not bytes or not isAlive() then return false end
        if u32(bytes,5)~=#pack.lengths then return false end
        local cursor=9
        for offset,expected in ipairs(pack.lengths) do
            if not isAlive() then return false end
            local length=u32(bytes,cursor);cursor=cursor+4
            if length~=expected or cursor+length-1>#bytes then return false end
            local jpeg=bytes:sub(cursor,cursor+length-1);cursor=cursor+length
            if jpeg:sub(1,3)~="\255\216\255" then return false end
            local ok=pcall(writefile,sheetPath(pack.first+offset-1),jpeg)
            if not ok then return false end
            if offset%3==0 then task.wait() end
        end
        if cursor~=#bytes+1 then return false end
    end
    for offset=1,#pack.lengths do
        if not isAlive() then return false end
        local index=pack.first+offset-1
        sheets[index]=asset(sheetPath(index))
        if not sheets[index] then return false end
    end
    return true
end
local function preloadSheet(index)
    if index>Config.sheets or not sheets[index] or not isAlive() then return end
    local slot=slots[(index-1)%#slots+1]
    if slot.index==index then return end
    -- Do not overwrite the last displayed atlas while the next one is buffering.
    if slot==showing then return end
    slot.index=index;slot.ready=false
    slot.image.Image=sheets[index]
    slot.image.ImageRectOffset=Vector2.new(0,0)
    -- Visible with tiny opacity while preparing: do not gate loading on IsLoaded.
    slot.image.ImageTransparency=.999;slot.image.ZIndex=1
    task.spawn(function()
        local ok=pcall(function() ContentProvider:PreloadAsync({slot.image}) end)
        if isAlive() and slot.index==index then slot.ready=ok or slot.image.IsLoaded end
    end)
end
local function readySheet(index)
    local slot=slots[(index-1)%#slots+1]
    if slot.index==index and (slot.ready or slot.image.IsLoaded) then return slot end
    return nil
end
local function opacity(slot,value)
    stage.BackgroundTransparency=1-value
    if slot then slot.image.ImageTransparency=1-value end
    if sound then sound.Volume=value end
end
local function run()
    screen=create("ScreenGui",parent,{Name="HzReyznHalloweenLoading",ResetOnSpawn=false,IgnoreGuiInset=true,
        DisplayOrder=100000,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
    pcall(function() screen.ScreenInsets=Enum.ScreenInsets.None end)
    screen:SetAttribute("PlaybackMode","Frames24")
    connect(screen.Destroying,function() cleanup(true) end)
    if owner then connect(owner.Destroying,function() cleanup(true) end) end
    stage=create("Frame",screen,{Name="MovieStage",Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(0,0,0),
        BackgroundTransparency=1,BorderSizePixel=0})
    for i=1,3 do
        local image=create("ImageLabel",stage,{Name="MovieFrames"..i,AnchorPoint=Vector2.new(.5,.5),
            Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Image="",
            ImageColor3=Color3.new(1,1,1),ImageTransparency=.999,Visible=true,
            ImageRectSize=Vector2.new(Config.width,Config.height),ScaleType=Enum.ScaleType.Stretch})
        slots[i]={image=image,index=0,ready=false}
    end
    local function resize()
        local size=stage.AbsoluteSize
        local height=math.min(size.Y,size.X*9/16)
        for _,slot in ipairs(slots) do slot.image.Size=UDim2.fromOffset(height*16/9,height) end
    end
    connect(stage:GetPropertyChangedSignal("AbsoluteSize"),resize);resize()
    local shield=create("TextButton",screen,{Name="InputShield",Size=UDim2.fromScale(1,1),Text="",
        BackgroundTransparency=1,AutoButtonColor=false,Active=true,Visible=false,ZIndex=10})
    if type(register)~="function" or type(writefile)~="function" then
        result="unavailable";warn("[HzReyzn] Local image/audio assets are unavailable in this client.");return
    end
    status("preparing")
    task.spawn(function()
        local path="HzReyzn_sequence_v3_soundtrack.ogg"
        if not cached(path,Config.audioBytes,"OggS") then
            local bytes=download("soundtrack.ogg",Config.audioBytes,"OggS")
            if bytes and isAlive() then pcall(writefile,path,bytes) else audioDone=true;return end
        end
        if isAlive() then audioUri=asset(path) or "";audioDone=true end
    end)
    -- Three bounded workers fetch small packs; only three atlas textures stay in UI.
    for _=1,3 do
        task.spawn(function()
            while isAlive() do
                local index=nextPack;nextPack=nextPack+1
                if index>#Config.packs then return end
                local ok,loaded=pcall(loadPack,index)
                if not ok or not loaded then packErrors[index]=true end
            end
        end)
    end
    local deadline=os.clock()+30
    while isAlive() do
        for i=1,3 do preloadSheet(i) end
        if readySheet(1) and audioDone and sheets[math.min(24,Config.sheets)] then break end
        if packErrors[1] or packErrors[2] or os.clock()>=deadline then
            result="unavailable";warn("[HzReyzn] Movie frame download or image loading failed.");return
        end
        task.wait(.03)
    end
    if not isAlive() then return end
    sound=create("Sound",screen,{Name="OriginalMovieAudio",SoundId=audioUri,Volume=0,Looped=false,PlaybackSpeed=1})
    local audioPreloaded=false
    task.spawn(function()
        pcall(function() ContentProvider:PreloadAsync({sound}) end);audioPreloaded=true
    end)
    deadline=os.clock()+5
    while isAlive() and not sound.IsLoaded and not audioPreloaded and os.clock()<deadline do task.wait(.03) end
    if not isAlive() then return end
    if audioUri=="" then warn("[HzReyzn] The movie soundtrack could not load.") end
    sound:Play();sound.TimePosition=0
    shield.Visible=true;status("playing")
    local elapsed,last,activeSlot=0,os.clock(),nil
    local bufferingAt
    while isAlive() and elapsed<Config.duration do
        local now=os.clock()
        local dt=math.min(now-last,.1);last=now
        local frame=math.min(Config.frames-1,math.floor(elapsed*Config.fps))
        local sheet=math.floor(frame/Config.perSheet)+1
        for i=sheet,math.min(sheet+2,Config.sheets) do preloadSheet(i) end
        local slot=readySheet(sheet)
        if not slot then
            if not bufferingAt then bufferingAt=now;sound:Pause();status("buffering") end
            if now-bufferingAt>20 then result="unavailable";warn("[HzReyzn] Timed out waiting for movie frames.");break end
            -- Preserve the last visible frame and pause its audio while fetching.
        else
            if bufferingAt then sound.TimePosition=elapsed;sound:Resume();bufferingAt=nil;status("playing") end
            if activeSlot~=slot then
                if activeSlot then activeSlot.image.ImageTransparency=.999;activeSlot.image.ZIndex=1 end
                activeSlot=slot;slot.image.ZIndex=2
                showing=slot
            end
            local cell=frame%Config.perSheet
            slot.image.ImageRectOffset=Vector2.new((cell%2)*Config.width,math.floor(cell/2)*Config.height)
            screen:SetAttribute("MovieFrame",frame)
            opacity(slot,math.min(smooth(elapsed/.7),smooth((Config.duration-elapsed)/.95)))
            if audioUri~="" and math.abs(sound.TimePosition-elapsed)>.18 then sound.TimePosition=elapsed end
            elapsed=elapsed+dt
        end
        RunService.Heartbeat:Wait()
    end
    if isAlive() and activeSlot then
        local initial=1-activeSlot.image.ImageTransparency
        local fadeStart=os.clock()
        while isAlive() and os.clock()-fadeStart<.25 do
            opacity(activeSlot,initial*(1-smooth((os.clock()-fadeStart)/.25)))
            RunService.Heartbeat:Wait()
        end
    end
    if isAlive() then status(result) end
end
local ok,err=xpcall(run,function(message) return tostring(message) end)
if not ok then result="unavailable";warn("[HzReyzn] Compatible movie playback: "..err) end
cleanup(false)
return result
