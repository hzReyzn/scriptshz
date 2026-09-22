-- HzReyzn Flight | Super Aura Blur (R15), bundle 19953018242407.
-- Catalog package IDs verified via Roblox bundle-details API.
-- Packages are containers, not AnimationTrack IDs. Resolve their Animation children.
-- Load failures are reported; no substituted/default poses, no client-only Animator.
local AuraPackages = {
    Idle=120958034769772, Walk=72284671228879, Run=110304356621538,
    Jump=87680156695778, Fall=132479078338047,
}
local resolvedAura = {}
local animationsReady, animationError = false, nil
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local old = playerGui:FindFirstChild("HZFlightStandalone")
if old then old:Destroy() end
local connections, characterConnections = {}, {}
local dead, flying, minimized = false, false, false
local speed = 50
local loadingFinished=false
local gfx = true
local wakePart, wakeBeams, wakeClock = nil, {}, 0
local up, down = false, false
local character, humanoid, root, animator, oldAuto, oldStand
local flightAttachment, velocityMover, orientationMover
local tracks, localObjects, emitters, trails = {}, {}, {}, {}
local trackName, state = nil, "Ready"
local smoothedVelocity = Vector3.zero
local takeoffAt, fallAt, clock = 0, nil, 0
local generation = 0
local accent = Color3.fromRGB(169,231,255)
local function connect(signal, callback, bucket)
    local c=signal:Connect(callback)
    table.insert(bucket or connections,c)
    return c
end
local function make(class,parent,props)
    local o=Instance.new(class)
    for k,v in pairs(props) do o[k]=v end
    o.Parent=parent
    return o
end
local function corner(o,r) make("UICorner",o,{CornerRadius=UDim.new(0,r or 9)}) end
local function tween(o,props,time)
    local t=TweenService:Create(o,TweenInfo.new(time or 0.18,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),props)
    t:Play();return t
end
local gui=make("ScreenGui",playerGui,{Name="HZFlightStandalone",ResetOnSpawn=false,DisplayOrder=65,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
local panel=make("CanvasGroup",gui,{Visible=false,GroupTransparency=1,Position=UDim2.new(0.5,-125,0.32,0),Size=UDim2.fromOffset(250,215),BackgroundColor3=Color3.fromRGB(9,20,32),BorderSizePixel=0,ClipsDescendants=true})
corner(panel,14)
local border=make("UIStroke",panel,{Color=accent,Thickness=1.7})
local scale=make("UIScale",panel,{Scale=1})
local header=make("TextLabel",panel,{Position=UDim2.fromOffset(12,0),Size=UDim2.fromOffset(158,39),BackgroundTransparency=1,Active=true,Text="HzReyzn Fly",TextXAlignment=Enum.TextXAlignment.Left,TextSize=14,Font=Enum.Font.GothamBold,TextColor3=accent})
local buttons={}
local function button(parent,text,x,y,w,h)
    local b=make("TextButton",parent,{Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),Text=text,Font=Enum.Font.GothamBold,TextSize=12,TextColor3=Color3.fromRGB(238,236,249),BackgroundColor3=Color3.fromRGB(24,47,65),BorderSizePixel=0,AutoButtonColor=true})
    corner(b,8);table.insert(buttons,b)
    local s=make("UIScale",b,{Scale=1})
    connect(b.InputBegan,function(i) if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then tween(s,{Scale=0.95},0.08) end end)
    connect(b.InputEnded,function(i) if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then tween(s,{Scale=1},0.16) end end)
    return b
end
local mini=button(panel,"−",178,6,28,27)
local close=button(panel,"×",213,6,28,27)
local body=make("Frame",panel,{Position=UDim2.fromOffset(0,39),Size=UDim2.fromOffset(250,176),BackgroundTransparency=1})
local toggle=button(body,"ON",10,0,230,36)
local minus=button(body,"−",10,43,35,30)
local speedBox=make("TextBox",body,{Position=UDim2.fromOffset(50,43),Size=UDim2.fromOffset(150,30),Text="50",ClearTextOnFocus=false,Font=Enum.Font.GothamBold,TextSize=14,TextColor3=Color3.new(1,1,1),BackgroundColor3=Color3.fromRGB(14,33,48),BorderSizePixel=0})
corner(speedBox,8)
local plus=button(body,"+",205,43,35,30)
local upButton=button(body,"↑  UP",10,80,112,33)
local downButton=button(body,"↓  DOWN",128,80,112,33)
local gfxButton=button(body,"VFX ON",10,120,230,29)
local status=make("TextLabel",body,{Visible=false,BackgroundTransparency=1,Text="Loading"})
make("TextLabel",body,{Position=UDim2.fromOffset(10,155),Size=UDim2.fromOffset(230,16),BackgroundTransparency=1,Text="Made By hzReyzn",TextSize=10,TextColor3=Color3.fromRGB(153,188,205),Font=Enum.Font.Gotham})
local loader=make("CanvasGroup",gui,{
    AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.42),
    Size=UDim2.fromOffset(278,112),BackgroundColor3=Color3.fromRGB(9,20,32),
    BorderSizePixel=0,GroupTransparency=1,
})
corner(loader,16)
make("UIStroke",loader,{Color=accent,Thickness=1.6,Transparency=0.12})
local loadTitle=make("TextLabel",loader,{
    Position=UDim2.fromOffset(12,20),Size=UDim2.fromOffset(254,38),
    BackgroundTransparency=1,Text="HzReyzn Fly",Font=Enum.Font.GothamBold,
    TextSize=25,TextColor3=Color3.fromRGB(231,250,255),
})
local shimmer=make("UIGradient",loadTitle,{
    Color=ColorSequence.new({ColorSequenceKeypoint.new(0,accent),ColorSequenceKeypoint.new(0.5,Color3.new(1,1,1)),ColorSequenceKeypoint.new(1,accent)}),
    Offset=Vector2.new(-1,0),
})
local rail=make("Frame",loader,{Position=UDim2.fromOffset(24,82),Size=UDim2.fromOffset(230,3),BackgroundColor3=Color3.fromRGB(25,53,70),BorderSizePixel=0})
corner(rail,2)
local fill=make("Frame",rail,{Size=UDim2.fromScale(0,1),BackgroundColor3=accent,BorderSizePixel=0})
corner(fill,2)
local loadStarted=os.clock()
local shimmerConnection=connect(RunService.RenderStepped,function()
    if loader.Parent then shimmer.Offset=Vector2.new(((os.clock()-loadStarted)*0.8)%2-1,0) end
end)
tween(loader,{GroupTransparency=0,Position=UDim2.fromScale(0.5,0.46)},0.4)
tween(fill,{Size=UDim2.fromScale(1,1)},3.9)
task.delay(3.9,function()
    if dead then return end
    tween(loader,{Position=UDim2.fromScale(0.5,1.25),GroupTransparency=1},0.6)
    task.delay(0.6,function()
        if dead then return end
        shimmerConnection:Disconnect();loader:Destroy();loadingFinished=true
        panel.Visible=true;tween(panel,{GroupTransparency=0},0.3)
    end)
end)
local drag,dragStart,startPos
connect(header.InputBegan,function(i)
    if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then drag=i;dragStart=i.Position;startPos=panel.Position end
end)
connect(UIS.InputChanged,function(i)
    if drag and (i==drag or i.UserInputType==Enum.UserInputType.MouseMovement) then
        local d=i.Position-dragStart
        panel.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
    end
end)
connect(UIS.InputEnded,function(i) if i==drag then drag=nil end end)
local resizeTween
connect(mini.Activated,function()
    minimized=not minimized;mini.Text=minimized and "+" or "−"
    if resizeTween then resizeTween:Cancel() end
    resizeTween=tween(panel,{Size=UDim2.fromOffset(250,minimized and 39 or 215)},0.25)
end)
local function setSpeed(n)
    if not n or n~=n or math.abs(n)==math.huge then n=speed end
    speed=math.clamp(math.floor(n+0.5),10,200);speedBox.Text=tostring(speed)
end
connect(minus.Activated,function() setSpeed(speed-10) end)
connect(plus.Activated,function() setSpeed(speed+10) end)
connect(speedBox.FocusLost,function() setSpeed(tonumber(speedBox.Text)) end)
local function paint()
    border.Color=accent;header.TextColor3=accent
    toggle.BackgroundColor3=flying and accent:Lerp(Color3.new(0,0,0),0.45) or Color3.fromRGB(24,47,65)
    for _,e in ipairs(emitters) do e.Color=ColorSequence.new(accent,Color3.new(1,1,1)) end
    for _,t in ipairs(trails) do t.Color=ColorSequence.new(accent,Color3.new(1,1,1)) end
end
connect(gfxButton.Activated,function()
    gfx=not gfx;gfxButton.Text=gfx and "VFX ON" or "VFX OFF"
    if not gfx then
        for _,e in ipairs(emitters) do e.Enabled=false;e:Clear() end
        for _,t in ipairs(trails) do t.Enabled=false;t:Clear() end
        for _,beam in ipairs(wakeBeams) do beam.Enabled=false end
    end
end)
local held={}
local function hold(b,key)
    connect(b.InputBegan,function(i)
        if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then held[i]=key;if key=="up" then up=true else down=true end end
    end)
end
hold(upButton,"up");hold(downButton,"down")
connect(UIS.InputEnded,function(i)
    held[i]=nil;up=false;down=false
    for _,key in pairs(held) do if key=="up" then up=true else down=true end end
end)
connect(UIS.WindowFocusReleased,function() table.clear(held);up=false;down=false;drag=nil end)
local function stopTracks()
    for _,t in pairs(tracks) do pcall(function() t:Stop(0.18) end) end
    trackName=nil
end
local currentTrack
local function play(name)
    local group=({Takeoff="Jump",Hover="Idle",Forward=speed<35 and "Walk" or "Run",
        Backward="Run",Left="Run",Right="Run",Up="Jump",Down="Fall",Fall="Fall"})[name]
    local t=tracks[group]
    if not t then return end
    t.Looped=name~="Takeoff" and name~="Fall"
    if currentTrack==t and t.IsPlaying then trackName=name;return end
    stopTracks();currentTrack=t;trackName=name
    local ok=pcall(function() t:Play(0.22,1,1) end)
    if not ok then animationError="Animation playback failed";animationsReady=false end
end
local function resolvePackage(group,id)
    if resolvedAura[group] then return resolvedAura[group] end
    -- Objects are never parented or run. Only read AnimationId, then destroy.
    local ok,objects=pcall(function() return game:GetObjects("rbxassetid://"..id) end)
    if not ok or type(objects)~="table" then return nil,"Cannot load "..group.." package" end
    local found={}
    for _,object in ipairs(objects) do
        if object:IsA("Animation") then table.insert(found,object) end
        for _,child in ipairs(object:GetDescendants()) do
            if child:IsA("Animation") then table.insert(found,child) end
        end
    end
    table.sort(found,function(x,y) return x:GetFullName()<y:GetFullName() end)
    local contentId=found[1] and found[1].AnimationId
    for _,object in ipairs(objects) do object:Destroy() end
    if not contentId or contentId=="" then return nil,"No Animation in "..group end
    resolvedAura[group]=contentId
    return contentId
end
local function loadTracks(token,h,sourceAnimator)
    local pending={}
    local function discard()
        for _,track in pairs(pending) do track:Destroy() end
    end
    local function fail(message)
        discard()
        if not dead and token==generation then animationError=message;animationsReady=false;status.Text=message;toggle.Text="ERROR";warn("HzReyzn Fly: "..message) end
        return false
    end
    if h.RigType~=Enum.HumanoidRigType.R15 then return fail("Super Aura Blur requires R15") end
    if not sourceAnimator then return fail("Character Animator missing") end
    for _,group in ipairs({"Idle","Walk","Run","Jump","Fall"}) do
        if dead or token~=generation then discard();return false end
        status.Text="Loading Aura: "..group
        local id,err=resolvePackage(group,AuraPackages[group])
        if dead or token~=generation then discard();return false end
        if not id then return fail(err) end
        local a=Instance.new("Animation");a.AnimationId=id
        local ok,t=pcall(function() return sourceAnimator:LoadAnimation(a) end)
        a:Destroy()
        if not ok then return fail("Cannot load "..group.." animation") end
        t.Priority=Enum.AnimationPriority.Action;t.Looped=true;pending[group]=t
    end
    local deadline=os.clock()+10
    while not dead and token==generation do
        local ready=true
        for _,t in pairs(pending) do if t.Length<=0 then ready=false;break end end
        if ready then break end
        if os.clock()>=deadline then return fail("Aura blocked or loading timed out") end
        task.wait(0.1)
    end
    if dead or token~=generation then discard();return false end
    tracks=pending;animationsReady=true;animationError=nil;currentTrack=nil
    return true
end
local function own(o) table.insert(localObjects,o);return o end
local function makeEffects()
    -- Local-only layered white/ice wake inspired by the reference video.
    for i,offset in ipairs({Vector3.new(-1.1,0,0),Vector3.new(1.1,0,0),Vector3.new(0,0.7,0),Vector3.new(0,-0.9,0)}) do
        local half=i<=2 and 0.46 or 0.72
        local a=own(make("Attachment",root,{Name="HZIceTrail",Position=offset-Vector3.new(half,0,0)}))
        local b=own(make("Attachment",root,{Name="HZIceTrail",Position=offset+Vector3.new(half,0,0)}))
        local trail=own(make("Trail",root,{
            Attachment0=a,Attachment1=b,Enabled=false,Lifetime=0.55,
            MinLength=0.05,FaceCamera=true,LightEmission=1,LightInfluence=0,
            WidthScale=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(0.35,0.8),NumberSequenceKeypoint.new(1,0)}),
            Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.12),NumberSequenceKeypoint.new(0.5,0.38),NumberSequenceKeypoint.new(1,1)}),
        }))
        table.insert(trails,trail)
    end
    local a=own(make("Attachment",root,{Name="HZIceAura"}))
    local e=own(make("ParticleEmitter",a,{
        Enabled=false,Rate=12,Lifetime=NumberRange.new(0.18,0.4),Speed=NumberRange.new(2,6),
        SpreadAngle=Vector2.new(180,180),Texture="rbxasset://textures/particles/sparkles_main.dds",
        LightEmission=1,LightInfluence=0,Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0.3),NumberSequenceKeypoint.new(1,0)}),
        Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.2),NumberSequenceKeypoint.new(1,1)}),
    }))
    table.insert(emitters,e)
    wakePart=own(make("Part",workspace,{Name="HZLocalIceWake",Size=Vector3.new(0.1,0.1,0.1),Transparency=1,Anchored=true,CanCollide=false,CanTouch=false,CanQuery=false,CastShadow=false}))
    for i=1,8 do
        local a0=make("Attachment",wakePart,{Name="WakeStart"..i})
        local a1=make("Attachment",wakePart,{Name="WakeEnd"..i})
        local beam=make("Beam",wakePart,{
            Attachment0=a0,Attachment1=a1,Enabled=false,FaceCamera=true,Segments=8,
            Width0=i<=2 and 0.6 or 0.09,Width1=0.015,LightEmission=1,LightInfluence=0,
            Color=ColorSequence.new(Color3.new(1,1,1),accent),
            Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.15),NumberSequenceKeypoint.new(0.7,0.4),NumberSequenceKeypoint.new(1,1)}),
        })
        table.insert(wakeBeams,beam)
    end
    paint()
end
local function updateWake(dt)
    if not wakePart or not root then return end
    local magnitude=smoothedVelocity.Magnitude
    local active=flying and gfx and magnitude>8
    for _,beam in ipairs(wakeBeams) do beam.Enabled=active end
    if not active then return end
    local heading=smoothedVelocity.Unit
    local axis=math.abs(heading.Y)>0.95 and Vector3.xAxis or Vector3.yAxis
    wakePart.CFrame=CFrame.lookAt(root.Position,root.Position+heading,axis)
    wakeClock=wakeClock+dt
    if wakeClock<0.055 then return end
    wakeClock=0
    local length=math.clamp(magnitude*0.3,8,42)
    for i,beam in ipairs(wakeBeams) do
        local angle=i*math.pi/4+clock*1.3
        local radius=i<=2 and 0.7 or 1.6
        local x,y=math.cos(angle)*radius,math.sin(angle)*radius
        beam.Attachment0.Position=Vector3.new(x,y,0.6)
        beam.Attachment1.Position=Vector3.new(x*1.8+math.sin(clock*13+i)*0.6,y*1.8,length*(0.7+i*0.035))
        beam.CurveSize0=math.sin(clock*9+i)*0.7
        beam.CurveSize1=math.cos(clock*8+i)*0.5
    end
end
local function releaseMovers()
    for _,o in ipairs({velocityMover,orientationMover,flightAttachment}) do if o then o:Destroy() end end
    velocityMover,orientationMover,flightAttachment=nil,nil,nil
end
local function endFlight(withFall)
    if not flying then return end
    flying=false;releaseMovers();smoothedVelocity=Vector3.zero
    if humanoid and humanoid.Parent then
        humanoid.AutoRotate=oldAuto;humanoid.PlatformStand=oldStand
        if humanoid.Health>0 and not oldStand then humanoid:ChangeState(Enum.HumanoidStateType.Freefall) end
    end
    toggle.Text="ON";paint()
    if withFall and humanoid and humanoid.Health>0 then fallAt=os.clock();state="Fall";play("Fall") else fallAt=nil;state="Ready";stopTracks() end
    for _,e in ipairs(emitters) do e.Enabled=false end
    for _,t in ipairs(trails) do t.Enabled=false end
    for _,beam in ipairs(wakeBeams) do beam.Enabled=false end
end
local function resetCharacter()
    endFlight(false);stopTracks();releaseMovers();fallAt=nil
    for _,c in ipairs(characterConnections) do c:Disconnect() end
    table.clear(characterConnections)
    for _,t in pairs(tracks) do pcall(function() t:Destroy() end) end
    for _,o in ipairs(localObjects) do o:Destroy() end
    tracks={};localObjects={};emitters={};trails={};wakeBeams={};wakePart=nil;animationsReady=false;currentTrack=nil
    character,humanoid,root,animator=nil,nil,nil,nil
    up=false;down=false;table.clear(held)
end
local function bind(model)
    generation=generation+1;local token=generation
    resetCharacter();status.Text="Waiting for character"
    task.spawn(function()
        local h=model:WaitForChild("Humanoid",10)
        local r=model:WaitForChild("HumanoidRootPart",10)
        if dead or token~=generation or not h or not r or player.Character~=model then return end
        character,humanoid,root=model,h,r
        animator=h:FindFirstChildOfClass("Animator")
        if not loadTracks(token,h,animator) then return end
        if dead or token~=generation then return end
        makeEffects()
        connect(h.Died,function() endFlight(false);fallAt=nil end,characterConnections)
        status.Text="Super Aura Blur · ready"
    end)
end
local function startFlight()
    if dead or not loadingFinished or flying or not humanoid or not root or not root.Parent or humanoid.Health<=0 then return end
    if not animationsReady then status.Text=animationError or "Loading Super Aura Blur";return end
    if humanoid.SeatPart or root.Anchored then status.Text="Stand up to fly";return end
    fallAt=nil;flying=true;takeoffAt=os.clock();oldAuto=humanoid.AutoRotate;oldStand=humanoid.PlatformStand
    humanoid.AutoRotate=false;humanoid.PlatformStand=true;humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    flightAttachment=make("Attachment",root,{Name="HZFlightControl"})
    velocityMover=make("LinearVelocity",root,{Name="HZFlightVelocity",Attachment0=flightAttachment,RelativeTo=Enum.ActuatorRelativeTo.World,VelocityConstraintMode=Enum.VelocityConstraintMode.Vector,ForceLimitsEnabled=false,VectorVelocity=Vector3.new(0,12,0)})
    orientationMover=make("AlignOrientation",root,{Name="HZFlightOrientation",Attachment0=flightAttachment,Mode=Enum.OrientationAlignmentMode.OneAttachment,MaxTorque=math.huge,Responsiveness=18,RigidityEnabled=false,CFrame=root.CFrame.Rotation})
    smoothedVelocity=Vector3.new(0,12,0);state="Takeoff";play(state)
    toggle.Text="OFF";paint()
    if gfx then for _,e in ipairs(emitters) do e:Emit(18) end end
end
local function toggleFlight() if flying then endFlight(true) else startFlight() end end
connect(toggle.Activated,toggleFlight)
connect(UIS.InputBegan,function(i,processed) if not processed and not UIS:GetFocusedTextBox() and i.KeyCode==Enum.KeyCode.F then toggleFlight() end end)
connect(player.CharacterAdded,bind)
connect(player.CharacterRemoving,function() generation=generation+1;resetCharacter() end)
local uiClock=0
connect(RunService.PreSimulation,function(dt)
    if dead or not root or not root.Parent or not humanoid then return end
    clock=clock+dt
    local now=os.clock()
    if flying then
        local camera=workspace.CurrentCamera
        if not camera then return end
        local look=camera.CFrame.LookVector
        local planar=Vector3.new(look.X,0,look.Z)
        if planar.Magnitude<0.01 then planar=Vector3.new(root.CFrame.LookVector.X,0,root.CFrame.LookVector.Z) end
        if planar.Magnitude<0.01 then planar=Vector3.new(0,0,-1) end
        planar=planar.Unit
        local right=Vector3.new(-planar.Z,0,planar.X)
        local move=humanoid.MoveDirection
        local f=move:Dot(planar);local lateral=move:Dot(right)
        local vertical=(up and 1 or 0)-(down and 1 or 0)
        if not UIS:GetFocusedTextBox() then
            if UIS:IsKeyDown(Enum.KeyCode.Space) or UIS:IsKeyDown(Enum.KeyCode.E) then vertical=vertical+1 end
            if UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.Q) then vertical=vertical-1 end
        end
        vertical=math.clamp(vertical,-1,1)
        local direction=planar*f+right*lateral+Vector3.new(0,vertical,0)
        if direction.Magnitude>1 then direction=direction.Unit end
        local target=direction*speed
        local nextState="Hover"
        if now-takeoffAt<0.3 then nextState="Takeoff";target=Vector3.new(0,12,0)
        elseif math.abs(vertical)>0.1 then nextState=vertical>0 and "Up" or "Down"
        elseif math.abs(f)>0.1 or math.abs(lateral)>0.1 then
            if math.abs(f)>=math.abs(lateral) then nextState=f>0 and "Forward" or "Backward" else nextState=lateral>0 and "Right" or "Left" end
        end
        state=nextState;play(state)
        smoothedVelocity=smoothedVelocity:Lerp(target,1-math.exp(-8*dt))
        velocityMover.VectorVelocity=smoothedVelocity
        local pitch=-f*math.rad(6)+vertical*math.rad(3)
        local roll=-lateral*math.rad(10)
        orientationMover.CFrame=CFrame.lookAt(Vector3.zero,planar)*CFrame.Angles(pitch,0,roll)
        for _,e in ipairs(emitters) do e.Enabled=gfx;e.Rate=direction.Magnitude>0.1 and 24 or 8 end
        for _,t in ipairs(trails) do t.Enabled=gfx and smoothedVelocity.Magnitude>8 end
        updateWake(dt)
    elseif fallAt then
        if now-fallAt>1.2 or humanoid.FloorMaterial~=Enum.Material.Air or humanoid.Health<=0 then fallAt=nil;state="Ready";stopTracks() end
    end
    uiClock=uiClock+dt
    if uiClock>0.15 and animationsReady then uiClock=0;status.Text=state..(flying and (" · "..speed) or " · Aura Blur") end
end)
connect(gui.Destroying,function()
    if dead then return end
    dead=true;generation=generation+1;resetCharacter()
    for _,c in ipairs(connections) do c:Disconnect() end
end)
connect(close.Activated,function() gui:Destroy() end)
if player.Character then bind(player.Character) end
