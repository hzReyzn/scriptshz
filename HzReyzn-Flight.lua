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
local speed, themeIndex, scaleIndex = 50, 1, 1
local gfx, poseEnabled = true, true
local up, down = false, false
local character, humanoid, root, animator, oldAuto, oldStand
local flightAttachment, velocityMover, orientationMover
local tracks, localObjects, emitters, trails = {}, {}, {}, {}
local trackName, state = nil, "Ready"
local smoothedVelocity = Vector3.zero
local takeoffAt, fallAt, clock = 0, nil, 0
local generation = 0
local themes = {Color3.fromRGB(177,95,255),Color3.fromRGB(67,179,255),Color3.fromRGB(68,224,164),Color3.fromRGB(255,99,144)}
local scales = {1,0.85,1.15}
local accent = themes[1]
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
local panel=make("Frame",gui,{Position=UDim2.new(0.5,-125,0.32,0),Size=UDim2.fromOffset(250,238),BackgroundColor3=Color3.fromRGB(16,15,25),BorderSizePixel=0,ClipsDescendants=true})
corner(panel,14)
local border=make("UIStroke",panel,{Color=accent,Thickness=1.7})
local scale=make("UIScale",panel,{Scale=1})
local header=make("TextLabel",panel,{Position=UDim2.fromOffset(12,0),Size=UDim2.fromOffset(158,39),BackgroundTransparency=1,Active=true,Text="HZ  /  FLIGHT",TextXAlignment=Enum.TextXAlignment.Left,TextSize=14,Font=Enum.Font.GothamBold,TextColor3=accent})
local buttons={}
local function button(parent,text,x,y,w,h)
    local b=make("TextButton",parent,{Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),Text=text,Font=Enum.Font.GothamBold,TextSize=12,TextColor3=Color3.fromRGB(238,236,249),BackgroundColor3=Color3.fromRGB(37,32,52),BorderSizePixel=0,AutoButtonColor=true})
    corner(b,8);table.insert(buttons,b)
    local s=make("UIScale",b,{Scale=1})
    connect(b.InputBegan,function(i) if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then tween(s,{Scale=0.95},0.08) end end)
    connect(b.InputEnded,function(i) if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then tween(s,{Scale=1},0.16) end end)
    return b
end
local mini=button(panel,"−",178,6,28,27)
local close=button(panel,"×",213,6,28,27)
local body=make("Frame",panel,{Position=UDim2.fromOffset(0,39),Size=UDim2.fromOffset(250,199),BackgroundTransparency=1})
local toggle=button(body,"FLY  /  OFF",10,0,230,36)
local minus=button(body,"−",10,43,35,30)
local speedBox=make("TextBox",body,{Position=UDim2.fromOffset(50,43),Size=UDim2.fromOffset(150,30),Text="50",ClearTextOnFocus=false,Font=Enum.Font.GothamBold,TextSize=14,TextColor3=Color3.new(1,1,1),BackgroundColor3=Color3.fromRGB(26,24,38),BorderSizePixel=0})
corner(speedBox,8)
local plus=button(body,"+",205,43,35,30)
local upButton=button(body,"↑  UP",10,80,112,33)
local downButton=button(body,"↓  DOWN",128,80,112,33)
local themeButton=button(body,"COLOR",10,120,70,27)
local gfxButton=button(body,"GFX ON",87,120,76,27)
local sizeButton=button(body,"SIZE",170,120,70,27)
local poseButton=button(body,"ANIM ON",10,153,94,26)
local status=make("TextLabel",body,{Position=UDim2.fromOffset(109,151),Size=UDim2.fromOffset(132,30),BackgroundTransparency=1,Text="Ready",TextSize=10,TextWrapped=true,TextColor3=Color3.fromRGB(177,170,193),Font=Enum.Font.Gotham})
make("TextLabel",body,{Position=UDim2.fromOffset(10,181),Size=UDim2.fromOffset(230,15),BackgroundTransparency=1,Text="Joystick / WASD · Space ↑ · Ctrl ↓ · F",TextSize=9,TextColor3=Color3.fromRGB(142,136,157),Font=Enum.Font.Gotham})
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
    resizeTween=tween(panel,{Size=UDim2.fromOffset(250,minimized and 39 or 238)},0.25)
end)
local function setSpeed(n)
    if not n or n~=n or math.abs(n)==math.huge then n=speed end
    speed=math.clamp(math.floor(n+0.5),10,200);speedBox.Text=tostring(speed)
end
connect(minus.Activated,function() setSpeed(speed-10) end)
connect(plus.Activated,function() setSpeed(speed+10) end)
connect(speedBox.FocusLost,function() setSpeed(tonumber(speedBox.Text)) end)
local function paint()
    accent=themes[themeIndex];border.Color=accent;header.TextColor3=accent
    toggle.BackgroundColor3=flying and accent:Lerp(Color3.new(0,0,0),0.45) or Color3.fromRGB(37,32,52)
    for _,e in ipairs(emitters) do e.Color=ColorSequence.new(accent,Color3.new(1,1,1)) end
    for _,t in ipairs(trails) do t.Color=ColorSequence.new(accent,Color3.new(1,1,1)) end
end
connect(themeButton.Activated,function() themeIndex=themeIndex%#themes+1;paint() end)
connect(sizeButton.Activated,function() scaleIndex=scaleIndex%#scales+1;tween(scale,{Scale=scales[scaleIndex]}) end)
connect(gfxButton.Activated,function() gfx=not gfx;gfxButton.Text=gfx and "GFX ON" or "GFX OFF" end)
connect(poseButton.Activated,function() poseEnabled=not poseEnabled;poseButton.Text=poseEnabled and "POSES ON" or "ANIM OFF" end)
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
    if not poseEnabled then stopTracks();currentTrack=nil;return end
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
        if not dead and token==generation then animationError=message;animationsReady=false;status.Text=message end
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
    for _,name in ipairs({"LeftHand","RightHand","Left Arm","Right Arm"}) do
        local limb=character:FindFirstChild(name)
        if limb and limb:IsA("BasePart") then
            local a=own(make("Attachment",limb,{Name="HZFlightFX",Position=Vector3.new(-0.2,-limb.Size.Y*0.4,0)}))
            local b=own(make("Attachment",limb,{Name="HZFlightFX",Position=Vector3.new(0.2,-limb.Size.Y*0.4,0)}))
            local trail=own(make("Trail",limb,{Attachment0=a,Attachment1=b,Enabled=false,Lifetime=0.3,MinLength=0.05,FaceCamera=true,LightEmission=0.85,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.25),NumberSequenceKeypoint.new(1,1)})}))
            table.insert(trails,trail)
        end
    end
    local a=own(make("Attachment",root,{Name="HZFlightAura",Position=Vector3.new(0,-1,0)}))
    local e=own(make("ParticleEmitter",a,{Enabled=false,Rate=14,Lifetime=NumberRange.new(0.2,0.45),Speed=NumberRange.new(2,5),SpreadAngle=Vector2.new(35,35),EmissionDirection=Enum.NormalId.Bottom,Texture="rbxasset://textures/particles/sparkles_main.dds",LightEmission=1,Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0.16),NumberSequenceKeypoint.new(1,0)}),Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.3),NumberSequenceKeypoint.new(1,1)})}))
    table.insert(emitters,e);paint()
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
    toggle.Text="FLY  /  OFF";paint()
    if withFall and humanoid and humanoid.Health>0 then fallAt=os.clock();state="Fall";play("Fall") else fallAt=nil;state="Ready";stopTracks() end
    for _,e in ipairs(emitters) do e.Enabled=false end
    for _,t in ipairs(trails) do t.Enabled=false end
end
local function resetCharacter()
    endFlight(false);stopTracks();releaseMovers();fallAt=nil
    for _,c in ipairs(characterConnections) do c:Disconnect() end
    table.clear(characterConnections)
    for _,t in pairs(tracks) do pcall(function() t:Destroy() end) end
    for _,o in ipairs(localObjects) do o:Destroy() end
    tracks={};localObjects={};emitters={};trails={};animationsReady=false;currentTrack=nil
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
    if dead or flying or not humanoid or not root or not root.Parent or humanoid.Health<=0 then return end
    if not animationsReady then status.Text=animationError or "Loading Super Aura Blur";return end
    if humanoid.SeatPart or root.Anchored then status.Text="Stand up to fly";return end
    fallAt=nil;flying=true;takeoffAt=os.clock();oldAuto=humanoid.AutoRotate;oldStand=humanoid.PlatformStand
    humanoid.AutoRotate=false;humanoid.PlatformStand=true;humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    flightAttachment=make("Attachment",root,{Name="HZFlightControl"})
    velocityMover=make("LinearVelocity",root,{Name="HZFlightVelocity",Attachment0=flightAttachment,RelativeTo=Enum.ActuatorRelativeTo.World,VelocityConstraintMode=Enum.VelocityConstraintMode.Vector,ForceLimitsEnabled=false,VectorVelocity=Vector3.new(0,12,0)})
    orientationMover=make("AlignOrientation",root,{Name="HZFlightOrientation",Attachment0=flightAttachment,Mode=Enum.OrientationAlignmentMode.OneAttachment,MaxTorque=math.huge,Responsiveness=18,RigidityEnabled=false,CFrame=root.CFrame.Rotation})
    smoothedVelocity=Vector3.new(0,12,0);state="Takeoff";play(state)
    toggle.Text="FLY  /  ON";paint()
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
