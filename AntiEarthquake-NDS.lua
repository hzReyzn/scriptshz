-- HzReyzn Anti Earthquake: standalone test, horizontal stabilization only.
local Players=game:GetService('Players')
local Run=game:GetService('RunService')
local UIS=game:GetService('UserInputService')
local player=Players.LocalPlayer
local pg=player:WaitForChild('PlayerGui')
local old=pg:FindFirstChild('HZAntiEarthquake')
if old then old:Destroy() end
local gui=Instance.new('ScreenGui');gui.Name='HZAntiEarthquake';gui.ResetOnSpawn=false;gui.Parent=pg
local frame=Instance.new('Frame');frame.Size=UDim2.fromOffset(250,104);frame.Position=UDim2.fromScale(.35,.25);frame.BackgroundColor3=Color3.fromRGB(13,19,40);frame.Parent=gui
local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(0,12);corner.Parent=frame
local function button(text,pos,size)
 local b=Instance.new('TextButton');b.Text=text;b.Position=pos;b.Size=size;b.BackgroundColor3=Color3.fromRGB(43,77,165);b.TextColor3=Color3.new(1,1,1);b.Font=Enum.Font.GothamBold;b.TextSize=13;b.Parent=frame
 local c=Instance.new('UICorner');c.Parent=b
 return b
end
local title=button('HzReyzn | Anti Earthquake',UDim2.fromOffset(8,7),UDim2.fromOffset(204,30))
local close=button('×',UDim2.fromOffset(218,7),UDim2.fromOffset(25,30))
local toggle=button('OFF',UDim2.fromOffset(10,49),UDim2.fromOffset(230,42))
local enabled=false
local cons={}
local function connect(signal,fn) local c=signal:Connect(fn);table.insert(cons,c);return c end
local attachment,mover,boundRoot,hold
local idleTrack,idleHum,idleAttempt=nil,nil,0
local function releaseIdle()
 if idleTrack then idleTrack:Stop(.15);idleTrack:Destroy() end
 idleTrack,idleHum=nil,nil
end
local function updateIdle(char,h,active)
 if not active then
  if idleTrack and idleTrack.IsPlaying then idleTrack:Stop(.08) end
  return
 end
 if idleHum~=h then releaseIdle();idleAttempt=0 end
 if not idleTrack and os.clock()>=idleAttempt then
  idleAttempt=os.clock()+2
  local animate=char:FindFirstChild('Animate')
  local folder=animate and animate:FindFirstChild('idle')
  local animator=h:FindFirstChildOfClass('Animator')
  local chosen,bestWeight=nil,-1
  if folder then
   for _,a in ipairs(folder:GetDescendants()) do
    if a:IsA('Animation') and a.AnimationId~='' then
     local w=a:FindFirstChild('Weight');local weight=w and w.Value or 1
     if weight>bestWeight then chosen=a;bestWeight=weight end
    end
   end
  end
  if chosen and animator then
   local ok,t=pcall(function() return animator:LoadAnimation(chosen) end)
   if ok then idleTrack=t;idleHum=h;t.Priority=Enum.AnimationPriority.Movement;t.Looped=true end

  end
 end
 if idleTrack then
  -- Overlay only our idle; leave the character's native animation tracks running.
  if not idleTrack.IsPlaying then idleTrack:Play(.18) end
 end
end
local nearby,nextScan={},0
local overlap=OverlapParams.new();overlap.FilterType=Enum.RaycastFilterType.Exclude
local function belongsToCharacter(part)
 local a=part
 while a and a~=workspace do
  if a:IsA('Model') and a:FindFirstChildOfClass('Humanoid') then return true end
  if a:IsA('Tool') then return true end
  a=a.Parent
 end
 return false
end
local function dampNearby(char,r,dt)
 if os.clock()>=nextScan then
  nextScan=os.clock()+.12;nearby={};overlap.FilterDescendantsInstances={char}
  local seen={}
  for _,part in ipairs(workspace:GetPartBoundsInRadius(r.Position,8,overlap)) do
   local assembly=part.AssemblyRootPart
   if assembly and not assembly.Anchored and not seen[assembly] then
    seen[assembly]=true
    local safe=not belongsToCharacter(assembly)
    if safe then for _,connected in ipairs(assembly:GetConnectedParts(true)) do
     if belongsToCharacter(connected) then safe=false;break end
    end end
    if safe then table.insert(nearby,{part=part,root=assembly}) end
   end
  end
 end
 local factor=math.exp(-18*math.clamp(dt,0,.1))
 for _,entry in ipairs(nearby) do
  local part,assembly=entry.part,entry.root
  if part.Parent and assembly.Parent and not assembly.Anchored and not belongsToCharacter(assembly) then
   local point=part.CFrame:PointToObjectSpace(r.Position)
   local half=part.Size*.5
   local nearest=Vector3.new(math.clamp(point.X,-half.X,half.X),math.clamp(point.Y,-half.Y,half.Y),math.clamp(point.Z,-half.Z,half.Z))
   if (point-nearest).Magnitude<=8 then
    local v=assembly.AssemblyLinearVelocity
    assembly.AssemblyLinearVelocity=Vector3.new(v.X*factor,v.Y,v.Z*factor)
    assembly.AssemblyAngularVelocity=assembly.AssemblyAngularVelocity*factor
   end
  end
 end
end
local function clear()
 releaseIdle();nearby={};nextScan=0
 if mover then mover:Destroy() end
 if attachment then attachment:Destroy() end
 attachment,mover,boundRoot,hold=nil,nil,nil,nil
end
connect(toggle.Activated,function() enabled=not enabled;toggle.Text=enabled and 'ON' or 'OFF';clear() end)
local drag,start,pos
connect(title.InputBegan,function(i)
 if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then drag=i;start=i.Position;pos=frame.Position end
end)
connect(UIS.InputChanged,function(i)
 if drag and (i==drag or i.UserInputType==Enum.UserInputType.MouseMovement) then
 local d=i.Position-start;frame.Position=UDim2.new(pos.X.Scale,pos.X.Offset+d.X,pos.Y.Scale,pos.Y.Offset+d.Y) end
end)
connect(UIS.InputEnded,function(i) if i==drag then drag=nil end end)
connect(Run.PreSimulation,function(dt)
 local char=player.Character
 local h=char and char:FindFirstChildOfClass('Humanoid')
 local r=char and char:FindFirstChild('HumanoidRootPart')
 if not enabled or not h or not r or h.Health<=0 or r.Anchored or h.SeatPart or h.PlatformStand or r:FindFirstChild('HZFlightVelocity') then clear();return end
 if boundRoot~=r then
  clear();boundRoot=r
  attachment=Instance.new('Attachment');attachment.Name='HZQuakeAttachment';attachment.Parent=r
  mover=Instance.new('LinearVelocity');mover.Name='HZQuakeStabilizer';mover.Attachment0=attachment
  mover.RelativeTo=Enum.ActuatorRelativeTo.World;mover.VelocityConstraintMode=Enum.VelocityConstraintMode.Plane
  mover.PrimaryTangentAxis=Vector3.xAxis;mover.SecondaryTangentAxis=Vector3.zAxis
  mover.ForceLimitsEnabled=true;mover.ForceLimitMode=Enum.ForceLimitMode.Magnitude
  mover.Enabled=false;mover.Parent=r
 end
 local state=h:GetState()
 local grounded=h.FloorMaterial~=Enum.Material.Air and not h.Jump and state~=Enum.HumanoidStateType.Jumping and state~=Enum.HumanoidStateType.Freefall
 mover.Enabled=grounded
 if not grounded then hold=nil;updateIdle(char,h,false);dampNearby(char,r,dt);return end
 mover.MaxForce=math.max(r.AssemblyMass,1)*6000
 local move=h.MoveDirection
 updateIdle(char,h,move.Magnitude<=.05)
 dampNearby(char,r,dt)
 local target=Vector3.new(move.X,0,move.Z)*h.WalkSpeed
 if move.Magnitude>.05 then hold=nil else
  hold=hold or r.Position
  local error=Vector3.new(hold.X-r.Position.X,0,hold.Z-r.Position.Z)
  if error.Magnitude>8 then hold=r.Position;error=Vector3.zero end
  target=error*12
  if target.Magnitude>20 then target=target.Unit*20 end
 end
 mover.PlaneVelocity=Vector2.new(target.X,target.Z)
end)
connect(gui.Destroying,function() clear();for _,c in ipairs(cons) do c:Disconnect() end end)
connect(close.Activated,function() gui:Destroy() end)
