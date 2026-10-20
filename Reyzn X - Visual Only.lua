--[[
    REYZN X | VISUAL-ONLY GUI RECREATION
    Standalone preview based on the available Reyzn X family visual style.
    No gameplay functions, remotes, loadstrings, movement edits or game actions.
    Tabs, buttons, toggles, draggable movement and minimize are VISUAL interactions.
    This file does not reference, import, or modify the original Reyzn X.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
if not player then return end

local old = player:WaitForChild("PlayerGui"):FindFirstChild("ReyznX_VisualPreview")
if old then old:Destroy() end

local C = {
    obsidian = Color3.fromRGB(10,10,15),
    black = Color3.fromRGB(18,17,25),
    graphite = Color3.fromRGB(27,26,36),
    violet = Color3.fromRGB(157,103,239),
    deep = Color3.fromRGB(60,31,99),
    pink = Color3.fromRGB(212,152,219),
    cyan = Color3.fromRGB(141,220,255),
    chrome = Color3.fromRGB(235,237,247),
    silver = Color3.fromRGB(184,181,201),
    muted = Color3.fromRGB(130,127,150)
}
local FONT = Enum.Font.Gotham
local FONT_BOLD = Enum.Font.GothamBold
local function create(class, parent, props)
    local object = Instance.new(class)
    for key,value in pairs(props or {}) do object[key] = value end
    object.Parent = parent
    return object
end
local function corner(target, radius)
    return create("UICorner",target,{CornerRadius=UDim.new(0,radius)})
end
local function gradient(target, colors, rotation)
    local points = {}
    for i,color in ipairs(colors) do
        points[i] = ColorSequenceKeypoint.new((i-1)/(#colors-1),color)
    end
    return create("UIGradient",target,{Color=ColorSequence.new(points),Rotation=rotation or 25})
end
local function edge(target, thickness, transparency)
    local stroke = create("UIStroke",target,{
        ApplyStrokeMode=Enum.ApplyStrokeMode.Border,
        Thickness=thickness or 1, Transparency=transparency or .4,
        Color=C.chrome
    })
    local shine = gradient(stroke,{C.deep,C.violet,C.chrome,C.cyan,C.deep},30)
    return stroke,shine
end
local function tween(target, time, properties)
    local motion = TweenService:Create(target,TweenInfo.new(time,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),properties)
    motion:Play()
    return motion
end
local function label(parent,text,x,y,w,h,size,bold,color,z)
    return create("TextLabel",parent,{
        BackgroundTransparency=1,Position=UDim2.fromOffset(x,y),
        Size=UDim2.fromOffset(w,h),Text=text,TextXAlignment=Enum.TextXAlignment.Left,
        TextColor3=color or C.chrome,Font=bold and FONT_BOLD or FONT,
        TextSize=size or 13,TextTruncate=Enum.TextTruncate.AtEnd,
        ZIndex=z or 8
    })
end

local screen = create("ScreenGui",player.PlayerGui,{
    Name="ReyznX_VisualPreview",IgnoreGuiInset=true,ResetOnSpawn=false,
    ZIndexBehavior=Enum.ZIndexBehavior.Sibling,DisplayOrder=125
})
local BASE_W,BASE_H = 690,460
local window = create("Frame",screen,{
    Name="ReyznX_Window",AnchorPoint=Vector2.new(.5,.5),
    Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(BASE_W,BASE_H),
    BackgroundTransparency=1,ClipsDescendants=false,ZIndex=1,Active=true
})
local responsive = create("UIScale",window,{Scale=1})
local appear = Instance.new("NumberValue")
appear.Value=1
appear.Name="WindowAnimationScale"
appear.Parent=screen
local layoutScale=1
local function refreshScale()
    local camera = workspace.CurrentCamera
    if not camera then return end
    local view = camera.ViewportSize
    layoutScale = math.clamp(math.min((view.X-20)/BASE_W,(view.Y-25)/BASE_H),.42,1.12)
    responsive.Scale=layoutScale*appear.Value
end
refreshScale()
local cameraChanged
local function connectCamera()
    if cameraChanged then cameraChanged:Disconnect() end
    if workspace.CurrentCamera then
        cameraChanged=workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(refreshScale)
    end
    refreshScale()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(connectCamera)
connectCamera()

-- Animated outline and amethyst-colored fire. Everything is created locally.
local movingFlames={}
local movingEmbers={}
local outlineGradients={}
local function addFlame(parent,x,y,height,width,rotation,z,seed)
    local flame = create("Frame",parent,{
        Name="VioletFlame",AnchorPoint=Vector2.new(.5,1),
        Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(width,height),
        BackgroundColor3=C.chrome,BackgroundTransparency=.44,
        BorderSizePixel=0,Rotation=rotation or 0,ZIndex=z or 3,Active=false
    })
    create("UICorner",flame,{CornerRadius=UDim.new(1,0)})
    local wash=gradient(flame,{C.pink,C.violet,C.deep,C.cyan},90)
    wash.Transparency=NumberSequence.new({
        NumberSequenceKeypoint.new(0,.18),
        NumberSequenceKeypoint.new(.42,.02),
        NumberSequenceKeypoint.new(1,1)
    })
    local core=create("Frame",flame,{
        Size=UDim2.new(.48,0,.6,0),Position=UDim2.fromScale(.26,.37),
        BackgroundColor3=C.cyan,BackgroundTransparency=.68,
        BorderSizePixel=0,ZIndex=(z or 3)+1,Active=false
    })
    corner(core,20)
    gradient(core,{C.cyan,C.violet,C.pink},90)
    movingFlames[#movingFlames+1]={
        obj=flame,x=x,y=y,height=height,width=width,
        rotation=rotation or 0,seed=seed or 0
    }
end
local function addEmber(parent,x,y,z,seed)
    local s=create("Frame",parent,{
        AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromOffset(x,y),
        Size=UDim2.fromOffset(2,3),BackgroundColor3=(seed%2==0 and C.cyan or C.pink),
        BackgroundTransparency=.35,BorderSizePixel=0,ZIndex=z,Active=false
    })
    corner(s,4)
    movingEmbers[#movingEmbers+1]={obj=s,x=x,y=y,seed=seed}
end
local fireLayer=create("Frame",window,{
    Name="AnimatedBorderFire",Size=UDim2.fromScale(1,1),
    BackgroundTransparency=1,BorderSizePixel=0,ZIndex=2,Active=false,ClipsDescendants=false
})
for i=1,13 do
    local x=18+(i-1)*54
    addFlame(fireLayer,x,459,24+(i%4)*8,12+(i%3)*4,((i%3)-1)*12,3,i*.41)
end
for i=1,11 do
    local x=24+(i-1)*63
    addFlame(fireLayer,x,19,23+(i%3)*7,12,173+(i%3)*7,3,i*.58+9)
end
for i=1,7 do
    local y=67+(i-1)*55
    addFlame(fireLayer,6,y,22+(i%3)*6,11,-78,3,i*.71+17)
    addFlame(fireLayer,684,y,22+(i%3)*6,11,75,3,i*.67+25)
end
for i=1,20 do
    local x=(i*109)%BASE_W
    local y=(i*67)%BASE_H
    if x<23 or x>BASE_W-23 or y<24 or y>BASE_H-24 then
        addEmber(fireLayer,x,y,5,i)
    end
end

local surface=create("Frame",window,{
    Name="ObsidianChromeSurface",Size=UDim2.fromScale(1,1),
    BackgroundColor3=C.obsidian,BorderSizePixel=0,ZIndex=4,Active=false
})
corner(surface,16)
gradient(surface,{Color3.fromRGB(33,29,46),C.obsidian,Color3.fromRGB(23,27,40)},25)
local border,borderShine=edge(surface,1.7,.15)
outlineGradients[#outlineGradients+1]=borderShine
for i=1,3 do
    local halo=create("Frame",window,{
        Name="AmethystHalo",Position=UDim2.fromOffset(-i*2,-i*2),
        Size=UDim2.new(1,i*4,1,i*4),BackgroundTransparency=1,
        BorderSizePixel=0,ZIndex=2,Active=false
    })
    corner(halo,16+i*2)
    local s,g=edge(halo,1.5,.78+i*.05)
    outlineGradients[#outlineGradients+1]=g
end

-- Header + brand
local header=create("Frame",surface,{
    BackgroundTransparency=1,Position=UDim2.fromOffset(16,13),
    Size=UDim2.fromOffset(658,68),ZIndex=9,Active=true
})
local logo=create("Frame",header,{
    Position=UDim2.fromOffset(3,3),Size=UDim2.fromOffset(58,58),
    BackgroundColor3=C.obsidian,BorderSizePixel=0,ZIndex=10
})
corner(logo,13)
gradient(logo,{C.deep,C.obsidian,C.graphite},28)
local logoBorder,logoShine=edge(logo,1.7,.2)
outlineGradients[#outlineGradients+1]=logoShine
local logoMark=create("TextLabel",logo,{
    Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Text="RX",
    TextColor3=C.chrome,TextSize=24,Font=FONT_BOLD,ZIndex=12
})
local logoTint=gradient(logoMark,{C.chrome,C.violet,C.cyan},0)
label(header,"REYZN X",75,7,280,28,25,true,C.chrome,11)
label(header,"OBSIDIAN  /  AMETHYST EDITION",77,35,310,16,10,false,C.silver,11)
local visualTag=create("TextLabel",header,{
    Position=UDim2.fromOffset(402,19),Size=UDim2.fromOffset(156,26),
    BackgroundColor3=C.graphite,Text="●  VISUAL ONLY",
    TextColor3=C.cyan,Font=FONT_BOLD,TextSize=10,ZIndex=12
})
corner(visualTag,8);edge(visualTag,1,.73)
local function headerButton(x,symbol)
    local b=create("TextButton",header,{
        Position=UDim2.fromOffset(x,18),Size=UDim2.fromOffset(35,28),
        BackgroundColor3=C.graphite,Text=symbol,TextColor3=C.chrome,
        TextSize=17,Font=FONT_BOLD,AutoButtonColor=false,ZIndex=13
    })
    corner(b,8);edge(b,1,.6)
    b.MouseEnter:Connect(function()tween(b,.2,{BackgroundColor3=C.deep})end)
    b.MouseLeave:Connect(function()tween(b,.2,{BackgroundColor3=C.graphite})end)
    return b
end
local minimizeButton=headerButton(581,"−")
local closeButton=headerButton(624,"×")
local divider=create("Frame",surface,{
    Position=UDim2.fromOffset(19,80),Size=UDim2.fromOffset(652,1),
    BackgroundColor3=C.violet,BackgroundTransparency=.48,BorderSizePixel=0,ZIndex=8
})
gradient(divider,{C.deep,C.violet,C.cyan,C.deep},0)

-- Shared metal panels
local function metalPanel(name,x,y,w,h)
    local p=create("Frame",surface,{
        Name=name,Position=UDim2.fromOffset(x,y),
        Size=UDim2.fromOffset(w,h),BackgroundColor3=C.black,
        BorderSizePixel=0,ZIndex=6,Active=false
    })
    corner(p,12)
    gradient(p,{Color3.fromRGB(30,27,41),C.black,Color3.fromRGB(16,18,29)},35)
    local _,g=edge(p,1,.65)
    outlineGradients[#outlineGradients+1]=g
    return p
end
local sidebar=metalPanel("Sidebar",15,94,151,350)
local contentShell=metalPanel("ContentShell",177,94,498,350)
label(sidebar,"NAVIGATION",13,13,130,18,10,true,C.silver,8)
label(sidebar,"EXPLORE",13,30,130,13,9,false,C.muted,8)
local navScroll=create("ScrollingFrame",sidebar,{
    Position=UDim2.fromOffset(9,52),Size=UDim2.new(1,-18,1,-63),
    BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=2,
    ScrollBarImageColor3=C.violet,ScrollingDirection=Enum.ScrollingDirection.Y,
    CanvasSize=UDim2.fromOffset(0,0),ZIndex=8
})

local pages = {
    {name="HOME",icon="⌂",description="Welcome to Reyzn X",sections={
        {title="QUICK ACCESS",items={"Open Scripts","Explore Shaders","Appearance","What Is New"}},
        {title="DESIGN SHOWCASE",items={"Metal Buttons","Animated Fire","Chrome Outlines","Neon Feedback"}}
    }},
    {name="MAIN",icon="◆",description="Main interface components",sections={
        {title="PLAYER CONTROLS",items={"WalkSpeed","JumpPower","Infinite Jump","Noclip","Fly","Gravity"}},
        {title="UTILITY",items={"Reset Character","Toggle Overlay"}}
    }},
    {name="SCRIPTS",icon="▣",description="Script tiles (no execution)",sections={
        {title="SCRIPTS",items={"Script Slot 01","Script Slot 02","Script Slot 03","Script Slot 04","Execute (Preview)","Clear (Preview)"}}
    }},
    {name="SHADERS",icon="✧",description="Shader button previews",sections={
        {title="TIME & ATMOSPHERE",items={"Noon","Night","Sunset","Sunrise","Real Time"}},
        {title="WEATHER",items={"Rain","Snowfall","Default Lighting"}}
    }},
    {name="NDS",icon="◇",description="Natural Disaster menu preview",sections={
        {title="MOVEMENT",items={"Fly SuperHero","Infinite Jump","Float","Walk On Water"}},
        {title="PROTECTION",items={"No FallDamage","Anti Earthquake","Gravity"}}
    }},
    {name="NOT MINE",icon="□",description="Placeholders for credited features",sections={
        {title="COMMUNITY SLOTS",items={"Community Script 01","Community Script 02","Creator Credits","More Soon"}}
    }},
    {name="SETTINGS",icon="⚙",description="Design settings showcase",sections={
        {title="THEME PREVIEWS",items={"Obsidian","Amethyst","Chrome","Ocean"}},
        {title="INTERFACE",items={"GUI Animations","Neon Glow","Background Particles","Button Feedback"}}
    }},
    {name="OPTIONS",icon="☷",description="Extra visual controls",sections={
        {title="PREFERENCES",items={"Compact Mode","Show Status","Rounded Corners","Visual Reset"}},
        {title="CONTROLS",items={"Minimize GUI","Reopen GUI"}}
    }},
    {name="SERVER",icon="◎",description="Server button mockups",sections={
        {title="SERVER",items={"Rejoin Server","Server Hop","Few Players","Refresh List"}}
    }},
    {name="CHANGELOG",icon="≡",description="Demo build information",sections={
        {title="VISUAL REPLICA v1",items={"Metallic UI","Animated Amethyst Fire","Fluid Transitions","Mobile & PC"}},
        {title="SAFETY",items={"No Remote Calls","No Gameplay Actions"}}
    }}
}
local navButtons={}
local currentPage
local notification=label(surface,"DESIGN PREVIEW  •  ALL FEATURES DISCONNECTED",191,426,460,17,10,false,C.muted,12)
local pageTitle=label(contentShell,"HOME",16,11,455,23,20,true,C.chrome,9)
local pageDescription=label(contentShell,"",17,35,458,15,11,false,C.silver,9)
local underline=create("Frame",contentShell,{
    Position=UDim2.fromOffset(15,57),Size=UDim2.fromOffset(467,1),
    BackgroundColor3=C.violet,BackgroundTransparency=.3,BorderSizePixel=0,ZIndex=8
})
gradient(underline,{C.violet,C.cyan,C.deep},0)
local scroll=create("ScrollingFrame",contentShell,{
    Name="PreviewOnlyComponents",Position=UDim2.fromOffset(10,69),
    Size=UDim2.new(1,-20,1,-80),CanvasSize=UDim2.fromOffset(0,0),
    ScrollBarThickness=3,ScrollBarImageColor3=C.violet,
    ScrollingDirection=Enum.ScrollingDirection.Y,BackgroundTransparency=1,
    BorderSizePixel=0,ZIndex=8
})
local function pulse(button)
    local scale=button:FindFirstChildOfClass("UIScale")
    if not scale then scale=create("UIScale",button,{Scale=1})end
    tween(scale,.09,{Scale=.965})
    task.delay(.11,function()
        if scale and scale.Parent then tween(scale,.2,{Scale=1}) end
    end)
end
local function metalButton(parent,title,x,y,w)
    local button=create("TextButton",parent,{
        Name="VisualButton",Position=UDim2.fromOffset(x,y),
        Size=UDim2.fromOffset(w,43),BackgroundTransparency=1,
        Text="",AutoButtonColor=false,ZIndex=10
    })
    local face=create("Frame",button,{
        Name="MetalFace",Size=UDim2.fromScale(1,1),
        BackgroundColor3=C.graphite,BorderSizePixel=0,
        Active=false,ZIndex=10
    })
    corner(face,9)
    gradient(face,{Color3.fromRGB(47,30,69),C.obsidian,Color3.fromRGB(37,45,63)},27)
    local s=edge(face,1,.57)
    local text=label(face,"  ◇   "..title,11,0,w-15,43,12,true,C.chrome,12)
    local flash=create("Frame",face,{
        Name="PressFlash",Size=UDim2.fromScale(1,1),BackgroundColor3=C.cyan,
        BackgroundTransparency=1,BorderSizePixel=0,ZIndex=11,Active=false
    })
    corner(flash,9)
    gradient(flash,{C.deep,C.cyan,C.pink},0)
    button.MouseEnter:Connect(function()
        if face.Parent then tween(s,.18,{Transparency=.2}) end
    end)
    button.MouseLeave:Connect(function()
        if face.Parent then tween(s,.2,{Transparency=.57}) end
    end)
    local toggled=false
    button.Activated:Connect(function()
        toggled=not toggled
        pulse(button)
        if flash.Parent then
            flash.BackgroundTransparency=.67
            tween(flash,.42,{BackgroundTransparency=1})
        end
        if text.Parent then
            text.Text=(toggled and "  ◆   " or "  ◇   ")..title
            text.TextColor3=toggled and C.cyan or C.chrome
        end
        notification.Text="VISUAL PREVIEW  •  "..title:upper().."  •  NO GAME ACTION"
    end)
    return button
end
local function loadPage(index)
    local page=pages[index]
    currentPage=index
    pageTitle.Text=page.name
    pageDescription.Text=page.description
    for _,o in ipairs(scroll:GetChildren()) do
        if o:IsA("GuiObject") then o:Destroy() end
    end
    local y=1
    for _,section in ipairs(page.sections) do
        label(scroll,section.title,6,y,440,20,10,true,C.cyan,10)
        y=y+25
        for i,feature in ipairs(section.items) do
            local col=(i-1)%2
            local row=math.floor((i-1)/2)
            metalButton(scroll,feature,7+col*235,y+row*50,219)
        end
        y=y+math.ceil(#section.items/2)*50+19
    end
    scroll.CanvasSize=UDim2.fromOffset(0,y+4)
    scroll.CanvasPosition=Vector2.new(0,0)
    for i,info in ipairs(navButtons) do
        local active=i==index
        tween(info.button,.19,{BackgroundColor3=active and C.deep or C.graphite})
        info.marker.Visible=active
        info.button.TextColor3=active and C.chrome or C.silver
    end
    notification.Text="DESIGN PREVIEW  •  "..page.name.."  •  NO GAME ACTIONS"
end
for i,page in ipairs(pages) do
    local b=create("TextButton",navScroll,{
        Position=UDim2.fromOffset(2,4+(i-1)*43),
        Size=UDim2.fromOffset(125,37),BackgroundColor3=C.graphite,
        Text=" "..page.icon.."   "..page.name,TextColor3=C.silver,
        Font=FONT_BOLD,TextSize=11,AutoButtonColor=false,
        TextXAlignment=Enum.TextXAlignment.Left,ZIndex=10
    })
    corner(b,8)
    local s=edge(b,1,.78)
    local selected=create("Frame",b,{
        Position=UDim2.fromOffset(0,8),Size=UDim2.fromOffset(3,21),
        BackgroundColor3=C.cyan,BorderSizePixel=0,ZIndex=12,Visible=false
    })
    corner(selected,3)
    b.MouseEnter:Connect(function()tween(s,.16,{Transparency=.25})end)
    b.MouseLeave:Connect(function()tween(s,.16,{Transparency=.78})end)
    b.Activated:Connect(function()pulse(b);loadPage(i)end)
    navButtons[i]={button=b,marker=selected}
end
navScroll.CanvasSize=UDim2.fromOffset(0,#pages*43+8)
loadPage(1)

-- Minimal square launcher with its own animated flame halo.
local launcher=create("TextButton",screen,{
    Name="ReyznX_OnlyLogoLauncher",AnchorPoint=Vector2.new(.5,.5),
    Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(70,70),
    BackgroundColor3=C.obsidian,Text="RX",TextColor3=C.chrome,
    Font=FONT_BOLD,TextSize=27,AutoButtonColor=false,
    Visible=false,ZIndex=50,ClipsDescendants=false
})
corner(launcher,16)
gradient(launcher,{C.deep,C.obsidian,C.graphite},28)
local launchStroke,launchGradient=edge(launcher,2,.12)
outlineGradients[#outlineGradients+1]=launchGradient
local launchScale=create("UIScale",launcher,{Scale=1})
for i=1,10 do
    local a=(i-1)*math.pi*2/10
    local x=35+math.cos(a)*34
    local y=35+math.sin(a)*34
    addFlame(launcher,x,y,19+(i%4)*5,9,math.deg(a)-90,49,32+i*.43)
end

local minimized=false
local busy=false
local function minimize(yes)
    if busy or minimized==yes then return end
    busy=true
    minimized=yes
    if yes then
        launcher.Position=window.Position
        launcher.Visible=true
        launchScale.Scale=.2
        tween(launchScale,.35,{Scale=1})
        local anim=tween(appear,.24,{Value=.65})
        anim.Completed:Once(function()
            if minimized then window.Visible=false end
            busy=false
        end)
    else
        window.Position=launcher.Position
        window.Visible=true
        appear.Value=.68
        tween(appear,.31,{Value=1})
        local anim=tween(launchScale,.25,{Scale=.2})
        anim.Completed:Once(function()
            if not minimized then launcher.Visible=false end
            launchScale.Scale=1
            busy=false
        end)
    end
end
minimizeButton.Activated:Connect(function()minimize(true)end)
launcher.Activated:Connect(function()minimize(false)end)
closeButton.Activated:Connect(function()
    -- Only close THIS visual preview, not the original Reyzn X.
    screen:Destroy()
end)

-- Dragging is presentation-only and supports mouse and touch.
local function enableDrag(handle,target)
    local held=false
    local dragInput,startPoint,startPosition
    handle.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or
            input.UserInputType==Enum.UserInputType.Touch then
            held=true
            dragInput=input
            startPoint=input.Position
            startPosition=target.Position
        end
    end)
    handle.InputEnded:Connect(function(input)
        if input==dragInput then held=false;dragInput=nil end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not held or not startPoint or not startPosition then return end
        if input.UserInputType~=Enum.UserInputType.MouseMovement
            and input.UserInputType~=Enum.UserInputType.Touch then return end
        if dragInput and dragInput.UserInputType==Enum.UserInputType.Touch
            and input~=dragInput then return end
        local delta=input.Position-startPoint
        target.Position=UDim2.new(
            startPosition.X.Scale,startPosition.X.Offset+delta.X/(target==window and layoutScale or 1),
            startPosition.Y.Scale,startPosition.Y.Offset+delta.Y/(target==window and layoutScale or 1))
    end)
end
enableDrag(header,window)
enableDrag(launcher,launcher)

local life=0
local timer=0
local beat
beat=RunService.Heartbeat:Connect(function(dt)
    if not screen.Parent then beat:Disconnect();return end
    timer=timer+dt
    if timer<1/30 then return end
    local frameDelta=timer
    timer=0
    life=life+frameDelta
    for _,f in ipairs(movingFlames) do
        if f.obj.Parent then
            local wave=math.sin(life*3.1+f.seed)
            local sway=math.sin(life*2.2+f.seed*1.7)
            local height=f.height*(.86+.20*(wave+1)/2)
            f.obj.Size=UDim2.fromOffset(f.width*(.94+.1*sway),height)
            f.obj.Position=UDim2.fromOffset(f.x+sway*2.5,f.y+math.sin(life*1.5+f.seed)*1.3)
            f.obj.Rotation=f.rotation+sway*7
            f.obj.BackgroundTransparency=.4+.16*(1+wave)/2
        end
    end
    for _,f in ipairs(movingEmbers) do
        if f.obj.Parent then
            local phase=(life*.3+f.seed*.137)%1
            f.obj.Position=UDim2.fromOffset(f.x+math.sin(life+f.seed)*5,f.y-phase*31)
            f.obj.BackgroundTransparency=.36+phase*.6
        end
    end
    for i,g in ipairs(outlineGradients) do
        if g.Parent then g.Offset=Vector2.new(math.sin(life*.39+i*.4)*.18,0) end
    end
    logoTint.Rotation=(life*8)%360
end)
screen.Destroying:Connect(function()
    if beat then beat:Disconnect() end
    if cameraChanged then cameraChanged:Disconnect() end
end)

-- No other code is loaded or called. All visible feature buttons are inert demos.
