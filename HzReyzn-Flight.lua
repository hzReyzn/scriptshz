-- HzReyzn Flight | independent R6/R15 client controller.
-- Custom procedural poses and VFX are LOCAL. Existing Animator tracks may replicate.
-- To replicate custom poses, assign published, rig-compatible animations authorized
-- for the experience below. Never creates a client-only Animator and claims replication.
local AnimationIds = {
    R6 = {}, R15 = {}, -- Keys: Takeoff, Hover, Forward, Backward, Left, Right, Up, Down, Fall
}
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
local motors, tracks, localObjects, emitters, trails = {}, {}, {}, {}, {}
local trackName, state = nil, "Ready"
local smoothedVelocity = Vector3.zero
local takeoffAt, fallAt, clock, poseWeight = 0, nil, 0, 0
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
local poseButton=button(body,"POSES ON",10,153,94,26)
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
connect(poseButton.Activated,function() poseEnabled=not poseEnabled;poseButton.Text=poseEnabled and "POSES ON" or "POSES OFF" end)
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
local function play(name)
    local t=tracks[name]
    if name==trackName then return end
    stopTracks();trackName=name
    if t then pcall(function() t:Play(0.22,1,1) end) end
end
local function loadTracks()
    if not animator then return end
    local rig=humanoid.RigType==Enum.HumanoidRigType.R6 and "R6" or "R15"
    local animate=character:FindFirstChild("Animate")
    local mapping={Takeoff="jump",Hover="swimidle",Forward="swim",Backward="swim",Left="swim",Right="swim",Up="jump",Down="fall",Fall="fall"}
    for name,group in pairs(mapping) do
        local id=AnimationIds[rig][name]
        if not id and animate then
            local folder=animate:FindFirstChild(group) or animate:FindFirstChild(name=="Takeoff" and "jump" or "idle")
            local a=folder and folder:FindFirstChildWhichIsA("Animation",true)
            id=a and a.AnimationId
        end
        if id and tostring(id)~="" then
            local a=Instance.new("Animation")
            a.AnimationId=tostring(id):match("^%d+$") and ("rbxassetid://"..tostring(id)) or tostring(id)
            local ok,t=pcall(function() return animator:LoadAnimation(a) end)
            a:Destroy()
            if ok then t.Priority=Enum.AnimationPriority.Action;t.Looped=name~="Takeoff" and name~="Fall";tracks[name]=t end
        end
    end
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
    for _,m in ipairs(motors) do if m.joint.Parent then m.joint.C0=m.base end end
    for _,t in pairs(tracks) do pcall(function() t:Destroy() end) end
    for _,o in ipairs(localObjects) do o:Destroy() end
    motors={};tracks={};localObjects={};emitters={};trails={};poseWeight=0
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
        for _,j in ipairs(model:GetDescendants()) do
            if j:IsA("Motor6D") and (j.Name=="RootJoint" or j.Name=="Root" or j.Name=="Waist" or j.Name=="Neck" or j.Name:find("Shoulder") or j.Name:find("Hip")) then table.insert(motors,{joint=j,base=j.C0}) end
        end
        loadTracks()
        if dead or token~=generation then return end
        makeEffects()
        connect(h.Died,function() endFlight(false);fallAt=nil end,characterConnections)
        status.Text="Ready · "..(h.RigType==Enum.HumanoidRigType.R6 and "R6" or "R15")
    end)
end
local function startFlight()
    if dead or flying or not humanoid or not root or not root.Parent or humanoid.Health<=0 then return end
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
local function poseFor(name,mode,t)
    local side=name:find("Left") and -1 or 1
    local wave=math.sin(t*2.6)*3
    local forward=mode=="Forward";local back=mode=="Backward"
    local rise=mode=="Up" or mode=="Takeoff"
    local fall=mode=="Fall" or mode=="Down"
    if name:find("Shoulder") then
        local pitch=forward and -75 or (rise and -125 or (back and 25 or (fall and -25 or -12)))
        local spread=fall and 55 or 25
        if mode=="Left" and side==-1 or mode=="Right" and side==1 then spread=70;pitch=-35 end
        return CFrame.Angles(math.rad(pitch+wave),0,math.rad(side*spread))
    elseif name:find("Hip") then
        return CFrame.Angles(math.rad((forward and 22 or (rise and -20 or (fall and -12 or 8)))+side*wave),0,math.rad(side*7))
    elseif name=="Neck" then return CFrame.Angles(math.rad(forward and 18 or (fall and -12 or 0)),0,0)
    elseif name=="Waist" then return CFrame.Angles(math.rad(forward and -12 or (back and 10 or 0)),0,0)
    end
    return CFrame.new()
end
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
        local pitch=-f*math.rad(24)+vertical*math.rad(8)
        local roll=-lateral*math.rad(23)
        orientationMover.CFrame=CFrame.lookAt(Vector3.zero,planar)*CFrame.Angles(pitch,0,roll)
        for _,e in ipairs(emitters) do e.Enabled=gfx;e.Rate=direction.Magnitude>0.1 and 24 or 8 end
        for _,t in ipairs(trails) do t.Enabled=gfx and smoothedVelocity.Magnitude>8 end
    elseif fallAt then
        if now-fallAt>1.2 or humanoid.FloorMaterial~=Enum.Material.Air or humanoid.Health<=0 then fallAt=nil;state="Ready";stopTracks() end
    end
    local goal=poseEnabled and (flying or fallAt~=nil) and 1 or 0
    poseWeight=poseWeight+(goal-poseWeight)*(1-math.exp(-10*dt))
    for _,m in ipairs(motors) do
        if m.joint.Parent and (goal>0 or poseWeight>0.0001) then
            local target=m.base*CFrame.new():Lerp(poseFor(m.joint.Name,state,clock),poseWeight)
            m.joint.C0=m.joint.C0:Lerp(target,1-math.exp(-12*dt))
            if goal==0 and poseWeight<0.001 then m.joint.C0=m.base end
        end
    end
    uiClock=uiClock+dt
    if uiClock>0.15 then uiClock=0;status.Text=state..(flying and (" · "..speed) or "") end
end)
connect(gui.Destroying,function()
    if dead then return end
    dead=true;generation=generation+1;resetCharacter()
    for _,c in ipairs(connections) do c:Disconnect() end
end)
connect(close.Activated,function() gui:Destroy() end)
if player.Character then bind(player.Character) end
