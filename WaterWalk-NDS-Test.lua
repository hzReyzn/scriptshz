-- HzReyzn Water Walk: independent, experimental NDS client test.
-- Detection: horizontal water-named parts, or Terrain water via raycast.
-- Does not disable disaster damage. No fixed or guessed ocean height.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local old = playerGui:FindFirstChild("HZWaterWalkTest")
if old then old:Destroy() end

local connections = {}
local stopped, enabled = false, false
local candidates = {}
local lastY, lastSource
local function connect(signal, callback)
    local c = signal:Connect(callback)
    table.insert(connections, c)
    return c
end
local function make(class, parent, props)
    local object = Instance.new(class)
    for k,v in pairs(props) do object[k]=v end
    object.Parent=parent
    return object
end
local function round(object)
    make("UICorner",object,{CornerRadius=UDim.new(0,10)})
end
local gui=make("ScreenGui",playerGui,{
    Name="HZWaterWalkTest",ResetOnSpawn=false,DisplayOrder=60,
    ZIndexBehavior=Enum.ZIndexBehavior.Sibling,
})
local panel=make("Frame",gui,{
    Size=UDim2.fromOffset(270,136),Position=UDim2.new(0.5,-135,0.28,0),
    BackgroundColor3=Color3.fromRGB(20,15,31),BorderSizePixel=0,
})
round(panel)
make("UIStroke",panel,{Color=Color3.fromRGB(190,100,240),Thickness=2})
local header=make("TextLabel",panel,{
    Size=UDim2.new(1,-42,0,38),BackgroundTransparency=1,Active=true,
    Text="HzReyzn | Water Walk",TextColor3=Color3.new(1,1,1),
    TextSize=15,Font=Enum.Font.GothamBold,
})
local close=make("TextButton",panel,{
    Position=UDim2.new(1,-36,0,5),Size=UDim2.fromOffset(30,30),
    BackgroundTransparency=1,Text="×",TextSize=24,TextColor3=Color3.new(1,1,1),
})
local toggle=make("TextButton",panel,{
    Position=UDim2.fromOffset(12,43),Size=UDim2.new(1,-24,0,40),
    BackgroundColor3=Color3.fromRGB(71,36,88),BorderSizePixel=0,
    Text="Water Walk: OFF",TextColor3=Color3.new(1,1,1),
    Font=Enum.Font.GothamBold,TextSize=14,
})
round(toggle)
local status=make("TextLabel",panel,{
    Position=UDim2.fromOffset(12,89),Size=UDim2.new(1,-24,0,38),
    BackgroundTransparency=1,Text="Activa cerca del agua",
    TextColor3=Color3.fromRGB(206,190,220),TextSize=12,TextWrapped=true,
    Font=Enum.Font.Gotham,
})
local pad=make("Part",workspace,{
    Name="HZWaterSupport",Size=Vector3.new(16,0.5,16),
    Anchored=true,Transparency=1,CanCollide=false,CanTouch=false,
    CanQuery=false,CastShadow=false,
})
local terrainParams=RaycastParams.new()
terrainParams.FilterType=Enum.RaycastFilterType.Include
terrainParams.FilterDescendantsInstances={workspace.Terrain}
terrainParams.IgnoreWater=false
local groundParams=RaycastParams.new()
groundParams.FilterType=Enum.RaycastFilterType.Exclude
groundParams.IgnoreWater=true
groundParams.RespectCanCollide=true

local function disablePad()
    pad.CanCollide=false
    lastY,lastSource=nil,nil
end
connect(gui.Destroying,function()
    if stopped then return end
    stopped=true
    for _,c in ipairs(connections) do c:Disconnect() end
    pad:Destroy()
    table.clear(candidates)
end)
connect(close.Activated,function() gui:Destroy() end)
connect(toggle.Activated,function()
    enabled=not enabled
    toggle.Text=enabled and "Water Walk: ON" or "Water Walk: OFF"
    toggle.BackgroundColor3=enabled and Color3.fromRGB(99,47,139) or Color3.fromRGB(71,36,88)
    if not enabled then disablePad();status.Text="Desactivado" end
end)
connect(player.CharacterAdded,disablePad)
connect(player.CharacterRemoving,disablePad)

-- Only the title drags the panel, leaving buttons free for touch.
local dragInput, dragStart, panelStart
connect(header.InputBegan,function(input)
    if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then
        dragInput=input;dragStart=input.Position;panelStart=panel.Position
    end
end)
connect(UIS.InputChanged,function(input)
    if not dragInput then return end
    if input~=dragInput and input.UserInputType~=Enum.UserInputType.MouseMovement then return end
    local delta=input.Position-dragStart
    panel.Position=UDim2.new(panelStart.X.Scale,panelStart.X.Offset+delta.X,panelStart.Y.Scale,panelStart.Y.Offset+delta.Y)
end)
connect(UIS.InputEnded,function(input)
    if input==dragInput then dragInput=nil end
end)

local function isWaterPart(part)
    if not part:IsA("BasePart") or part==pad then return false end
    if part.Size.X<12 or part.Size.Z<12 then return false end
    local named=false
    local node=part
    while node and node~=workspace do
        if node:IsA("Model") and node:FindFirstChildOfClass("Humanoid") then return false end
        local name=string.lower(node.Name)
        if name:find("water",1,true) or name:find("ocean",1,true)
            or name=="sea" or name=="flood" or name=="floodwater" then named=true end
        node=node.Parent
    end
    return named or part.Material==Enum.Material.Water
end
local function consider(part)
    if isWaterPart(part) then candidates[part]=true end
end
connect(workspace.DescendantAdded,function(part)
    task.defer(function()
        if not stopped and part:IsDescendantOf(workspace) then consider(part) end
    end)
end)
connect(workspace.DescendantRemoving,function(part) candidates[part]=nil end)
-- Periodic chunked discovery also catches parts renamed after parenting.
task.spawn(function()
    while not stopped do
        if enabled then
            local all=workspace:GetDescendants()
            for i,part in ipairs(all) do
                if stopped then return end
                consider(part)
                if i%350==0 then task.wait() end
            end
        end
        task.wait(3)
    end
end)

local function surfaceAt(position)
    local best,source
    for part in pairs(candidates) do
        if not part:IsDescendantOf(workspace) then
            candidates[part]=nil
        elseif part.Transparency<1 and isWaterPart(part) and part.CFrame.UpVector.Y>0.98 then
            local normal=part.CFrame.UpVector
            local top=part.Position+normal*(part.Size.Y*0.5)
            local y=top.Y-(normal.X*(position.X-top.X)+normal.Z*(position.Z-top.Z))/normal.Y
            local localPoint=part.CFrame:PointToObjectSpace(Vector3.new(position.X,y,position.Z))
            if math.abs(localPoint.X)<=part.Size.X*0.5 and math.abs(localPoint.Z)<=part.Size.Z*0.5 then
                if not best or y>best then best,source=y,part end
            end
        end
    end
    local hit=workspace:Raycast(position+Vector3.new(0,512,0),Vector3.new(0,-2048,0),terrainParams)
    if hit and hit.Material==Enum.Material.Water and (not best or hit.Position.Y>best) then
        best,source=hit.Position.Y,workspace.Terrain
    end
    return best,source
end

local uiClock=0
connect(RunService.PreSimulation,function(dt)
    if stopped or not enabled then return end
    local char=player.Character
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    local root=char and char:FindFirstChild("HumanoidRootPart")
    if not hum or not root or hum.Health<=0 or hum.SeatPart or root.Anchored then
        disablePad();status.Text="Esperando personaje";return
    end
    local y,source=surfaceAt(root.Position)
    if not y then
        disablePad();status.Text="No se detecta agua debajo";return
    end
    -- Keep feet above the detected surface, away from touch-based water damage.
    local targetY=y+1
    local leg=char:FindFirstChild("Left Leg")
    local feet=root.Position.Y-(hum.HipHeight+root.Size.Y*0.5+(leg and leg.Size.Y or 0))
    local grounded=pad.CanCollide and lastY and math.abs(feet-lastY)<0.8
        and not hum.Jump and hum:GetState()~=Enum.HumanoidStateType.Jumping
        and hum:GetState()~=Enum.HumanoidStateType.Freefall
    -- Carry only a character already standing on this pad, never teleport from land.
    if grounded and source==lastSource then
        local delta=targetY-lastY
        if math.abs(delta)<=12 then
            groundParams.FilterDescendantsInstances={char,pad}
            local ground=workspace:Raycast(root.Position,Vector3.new(0,-(root.Position.Y-feet+0.8),0),groundParams)
            if not ground then
                root.CFrame=root.CFrame+Vector3.new(0,delta,0)
                feet=feet+delta
            end
        end
    end
    pad.CFrame=CFrame.new(root.Position.X,targetY-pad.Size.Y*0.5,root.Position.Z)
    -- No collision while submerged: avoids snapping the character through the pad.
    pad.CanCollide=feet>=targetY-0.7
    lastY,lastSource=targetY,source
    uiClock=uiClock+dt
    if uiClock>=0.2 then
        uiClock=0
        status.Text=pad.CanCollide and string.format("%s | nivel %.1f",source.Name,y)
            or "Detectado: sube por encima del agua"
    end
end)
