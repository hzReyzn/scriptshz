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
local function clear()
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
connect(Run.PreSimulation,function()
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
 if not grounded then hold=nil;return end
 mover.MaxForce=math.max(r.AssemblyMass,1)*6000
 local move=h.MoveDirection
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
