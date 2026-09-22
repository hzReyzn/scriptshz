-- HzReyzn Water Walk: independent, experimental NDS client test.
-- Direct Workspace.WaterLevel tracking; no size, material, or query filters.
-- File-mesh surface height is approximated by its origin; use height adjustment.
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
local clearance = 3
local waterObject
local heightInfo = ""
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
    Size=UDim2.fromOffset(270,181),Position=UDim2.new(0.5,-135,0.28,0),
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
    BackgroundTransparency=1,Text="WaterLevel DIRECT | Activa para probar",
    TextColor3=Color3.fromRGB(206,190,220),TextSize=12,TextWrapped=true,
    Font=Enum.Font.Gotham,
})
local pad=make("Part",workspace,{
    Name="HZWaterSupport",Size=Vector3.new(16,0.5,16),
    Anchored=true,Transparency=1,CanCollide=false,CanTouch=false,
    CanQuery=false,CastShadow=false,
})
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

local minus=make("TextButton",panel,{
    Position=UDim2.fromOffset(12,135),Size=UDim2.fromOffset(38,32),
    Text="−",TextSize=20,TextColor3=Color3.new(1,1,1),
    BackgroundColor3=Color3.fromRGB(71,36,88),BorderSizePixel=0,
})
round(minus)
local plus=make("TextButton",panel,{
    Position=UDim2.fromOffset(220,135),Size=UDim2.fromOffset(38,32),
    Text="+",TextSize=20,TextColor3=Color3.new(1,1,1),
    BackgroundColor3=Color3.fromRGB(71,36,88),BorderSizePixel=0,
})
round(plus)
local heightLabel=make("TextLabel",panel,{
    Position=UDim2.fromOffset(52,135),Size=UDim2.fromOffset(166,32),
    Text="Separación: 3 studs",TextSize=13,TextColor3=Color3.new(1,1,1),
    BackgroundTransparency=1,Font=Enum.Font.Gotham,
})
local function adjust(delta)
    clearance=math.clamp(clearance+delta,-20,50)
    heightLabel.Text="Separación: "..clearance.." studs"
end
connect(minus.Activated,function() adjust(-1) end)
connect(plus.Activated,function() adjust(1) end)

local function surfaceAt(position)
    if not waterObject or waterObject.Parent~=workspace then
        waterObject=workspace:FindFirstChild("WaterLevel")
    end
    if not waterObject then heightInfo="Falta Workspace.WaterLevel";return end
    if waterObject:IsA("NumberValue") or waterObject:IsA("IntValue") then
        heightInfo="WaterLevel.Value"
        return waterObject.Value,waterObject
    end
    if not waterObject:IsA("BasePart") then
        heightInfo="WaterLevel es "..waterObject.ClassName
        return
    end
    local water=waterObject
    local mesh=water:FindFirstChildWhichIsA("DataModelMesh")
    local cf=water.CFrame
    local localY=water.Size.Y*0.5
    local origin=cf.Position
    if mesh then
        origin=cf:PointToWorldSpace(mesh.Offset)
        if mesh:IsA("BlockMesh") or
            (mesh:IsA("SpecialMesh") and mesh.MeshType==Enum.MeshType.Brick) then
            localY=water.Size.Y*math.abs(mesh.Scale.Y)*0.5
        else
            -- File/flat meshes do not expose rendered bounds through Part.Size.
            -- Follow their origin and offset instead; height control calibrates it.
            localY=0
        end
    end
    local normal=cf.UpVector
    if math.abs(normal.Y)<0.95 then
        heightInfo="WaterLevel inclinado: revisar propiedades";return
    end
    local top=origin+normal*localY
    local y=top.Y-(normal.X*(position.X-top.X)+normal.Z*(position.Z-top.Z))/normal.Y
    heightInfo=string.format("WaterLevel DIRECT | Y %.1f",y)
    return y,water
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
        disablePad();status.Text=heightInfo;return
    end
    -- Keep feet above the detected surface, away from touch-based water damage.
    local targetY=y+clearance
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
        status.Text=pad.CanCollide and heightInfo
            or (heightInfo.." | Sube encima de la plataforma")
    end
end)
