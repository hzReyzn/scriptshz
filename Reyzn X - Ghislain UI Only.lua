-- Reyzn X | Ghislain Amethyst Edition | UI-ONLY CLONE
-- Authentic UI components and VFX from hzReyzn/Ghislain.
-- No gameplay controller, teleport, remote execution, loadstring, or ability logic.
-- Original Ghislain/Reyzn X.lua and scriptshz/Reyzn X V1.lua remain untouched.
local Players = game:GetService("Players")
local Input = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")
local player = Players.LocalPlayer
if not player then return end
local startedAt = os.clock()
local playerGui = player:WaitForChild("PlayerGui")
local previousPreview=playerGui:FindFirstChild("ReyznX_Ghislain_VisualOnly")
if previousPreview then previousPreview:Destroy() end



-- Public version changes ONLY at the owner's explicit request.
local VERSION = "1.0"
local BUILD = "ghislain-ui-only-20261020"
-- Roblox Creator Store: Rajdhani, published by Roblox. Use FontFace, not
-- an invented Enum.Font entry. The brand and credit retain their own fonts.
local OPTION_FONT = Font.new("rbxassetid://12187375422",Enum.FontWeight.SemiBold,Enum.FontStyle.Normal)
local ICON_TRANSPARENCY, BACKGROUND_TRANSPARENCY = .85, .83
local VFX_RATE = 60 -- Ultra High is fixed; no automatic quality reduction.
local C = {
    base=Color3.fromRGB(10,10,15), panel=Color3.fromRGB(16,15,23),
    black=Color3.fromRGB(8,8,12), steel=Color3.fromRGB(71,68,85),
    silver=Color3.fromRGB(217,219,233), white=Color3.fromRGB(245,244,251),
    muted=Color3.fromRGB(184,181,201), line=Color3.fromRGB(66,59,85),
    violet=Color3.fromRGB(157,103,239), light=Color3.fromRGB(213,181,255),
    deep=Color3.fromRGB(60,31,99), green=Color3.fromRGB(132,225,179), ice=Color3.fromRGB(180,207,255),
    rose=Color3.fromRGB(212,152,219), chrome=Color3.fromRGB(235,237,247),
    pink=Color3.fromRGB(245,92,202), orchid=Color3.fromRGB(192,114,255),
    cyan=Color3.fromRGB(141,220,255),
}
local state = {alive=true, target="open", page="Home", paneOpen=true,
    lastSecond=-1, phase=0, budget=0, burst=0, finishAt=0, launcherMoved=false}
local UI, connections, threads, tweens = {}, {}, {}, {}
local features = {}
local scopes, alphaEntries, alphaLookup = {}, {}, {}
local factors = {window=0, pane=0, page=0, launcher=0, notification=0, disaster=0, fps=0, fixed=1}

local function connect(signal, callback)
    local c = signal:Connect(function(...) if state.alive then callback(...) end end)
    connections[#connections+1] = c
    return c
end
local function spawn(callback)
    local thread
    thread = task.defer(function() callback(); threads[thread]=nil end)
    threads[thread] = true
end
-- Transparency is composed from immutable base values. Transitions never sample
-- a half-faded frame, so repeated/reversed animations cannot progressively dim it.
local function registerAlpha(o, property, base, scope)
    local entry={object=o, property=property, base=base, scope=scope}
    alphaEntries[#alphaEntries+1]=entry
    alphaLookup[o]=alphaLookup[o] or {}; alphaLookup[o][property]=entry
    o[property]=1-(1-base)*(factors[scope] or 1)
end
local function alpha(o, property, base)
    local entry=alphaLookup[o] and alphaLookup[o][property]
    if entry then
        entry.base=base; o[property]=1-(1-base)*(factors[entry.scope] or 1)
    else o[property]=base end
end
local function refreshAlpha()
    factors.window=UI.windowFade.Value
    factors.pane=factors.window*UI.paneProgress.Value
    factors.page=factors.pane*UI.pageFade.Value
    factors.launcher=UI.launcherFade.Value
    factors.notification=UI.toastProgress and UI.toastProgress.Value or 0
    factors.disaster=UI.disasterProgress and UI.disasterProgress.Value or 0
    factors.fps=UI.fpsProgress and UI.fpsProgress.Value or 0
    for _,entry in ipairs(alphaEntries) do
        entry.object[entry.property]=1-(1-entry.base)*(factors[entry.scope] or 1)
    end
end
local function make(class, parent, props, scope)
    local o=Instance.new(class)
    for k,v in pairs(props or {}) do o[k]=v end
    if o:IsA("GuiObject") then o.BorderSizePixel=0; o.AutoLocalize=false end
    scopes[o]=scope or scopes[parent] or "fixed"
    o.Parent=parent
    if o:IsA("GuiObject") then
        registerAlpha(o,"BackgroundTransparency",o.BackgroundTransparency,scopes[o])
        if o:IsA("TextLabel") or o:IsA("TextButton") then
            o.TextStrokeTransparency=1
            registerAlpha(o,"TextTransparency",o.TextTransparency,scopes[o])
        end
        if o:IsA("ImageLabel") or o:IsA("ImageButton") then
            registerAlpha(o,"ImageTransparency",o.ImageTransparency,scopes[o])
        end
        if o:IsA("ScrollingFrame") then registerAlpha(o,"ScrollBarImageTransparency",o.ScrollBarImageTransparency,scopes[o]) end
    elseif o:IsA("UIStroke") then registerAlpha(o,"Transparency",o.Transparency,scopes[o]) end
    return o
end
local function tween(o, seconds, props)
    if not state.alive then return end
    if tweens[o] then tweens[o]:Cancel() end
    local t=TweenService:Create(o,TweenInfo.new(seconds,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),props)
    tweens[o]=t; t:Play()
end
local function corner(o,r) return make("UICorner",o,{CornerRadius=UDim.new(0,r or 12)}) end
local function stroke(o,color,opacity,width)
    return make("UIStroke",o,{Color=color or C.line,Transparency=opacity or 0,Thickness=width or 1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
end
local function gradient(o,colors,rotation)
    local keys={}
    for i,color in ipairs(colors) do keys[i]=ColorSequenceKeypoint.new((i-1)/(#colors-1),color) end
    return make("UIGradient",o,{Color=ColorSequence.new(keys),Rotation=rotation or 90})
end
local function fadeGradient(g)
    g.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.48,.08),NumberSequenceKeypoint.new(.52,.08),NumberSequenceKeypoint.new(1,1)})
end
local function frame(parent,name,pos,size,color,transparency,scope)
    return make("Frame",parent,{Name=name,Position=pos,Size=size,BackgroundColor3=color or C.panel,BackgroundTransparency=transparency or 0},scope)
end
local function label(parent,name,text,pos,size,pixels,color,font)
    local o=make("TextLabel",parent,{Name=name,Text=text,Position=pos,Size=size,BackgroundTransparency=1,
        TextColor3=color or C.white,TextSize=pixels or 14,Font=font~=OPTION_FONT and font or Enum.Font.GothamMedium,
        TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,TextTruncate=Enum.TextTruncate.AtEnd})
    if font==OPTION_FONT then o.FontFace=OPTION_FONT end
    return o
end
local function imageLabel(parent,name,pos,size)
    return make("ImageLabel",parent,{Name=name,Image="",Position=pos,Size=size,BackgroundTransparency=1,ScaleType=Enum.ScaleType.Fit})
end
local paths={
    crown={{{3,7},{6,17},{18,17},{21,7},{16,11},{12,3},{8,11},{3,7}},{{6,21},{18,21}}},
    home={{{3,11},{12,3},{21,11}},{{6,9},{6,21},{10,21},{10,15},{14,15},{14,21},{18,21},{18,9}}},
    cube={{{12,2},{22,7},{22,18},{12,23},{2,18},{2,7},{12,2}},{{2,7},{12,12},{22,7}},{{12,12},{12,23}}},
    spark={{{12,2},{15,9},{22,12},{15,15},{12,22},{9,15},{2,12},{9,9},{12,2}}},
    code={{{8,6},{2,12},{8,18}},{{16,6},{22,12},{16,18}},{{14,3},{10,21}}},
    settings={{{4,6},{20,6}},{{4,12},{20,12}},{{4,18},{20,18}},{{9,3},{9,9}},{{16,9},{16,15}},{{8,15},{8,21}}},
    arrow={{{4,12},{20,12}},{{14,6},{20,12},{14,18}}},
    close={{{6,6},{18,18}},{{18,6},{6,18}}},
    minimize={{{5,16},{19,16}}}, fold={{{14,5},{7,12},{14,19}}},
}
local artworkImages={IconHome={},IconMain={},IconVisuals={},IconScripts={},IconSettings={},Background={},Emblem={}}
local iconSprites={}
local iconAssets={home="IconHome",cube="IconMain",spark="IconVisuals",code="IconScripts",settings="IconSettings"}
local function icon(parent,kind,pos,size,color)
    local host=frame(parent,"Icon_"..kind,pos,UDim2.fromOffset(size,size),nil,1)
    local fallback={}
    for _,path in ipairs(paths[kind]) do
        for i=1,#path-1 do
            local a,b=path[i],path[i+1]; local dx,dy=(b[1]-a[1])*size/24,(b[2]-a[2])*size/24
            local line=frame(host,"Line",UDim2.fromOffset((a[1]+b[1])*size/48,(a[2]+b[2])*size/48),UDim2.fromOffset(math.sqrt(dx*dx+dy*dy),1.7),color or C.silver)
            line.AnchorPoint=Vector2.new(.5,.5); line.Rotation=math.deg(math.atan2(dy,dx)); corner(line,2)
            fallback[#fallback+1]=line
        end
    end
    local asset=iconAssets[kind]
    if asset then
        local artwork=imageLabel(host,"OptionArtwork",UDim2.fromScale(.5,.5),UDim2.fromScale(1.42,1.42))
        artwork.AnchorPoint=Vector2.new(.5,.5);artwork.Active=false
        alpha(artwork,"ImageTransparency",ICON_TRANSPARENCY)
        artworkImages[asset][#artworkImages[asset]+1]=artwork
        iconSprites[#iconSprites+1]={image=artwork,fallback=fallback,key=asset}
    end
    return host
end
local function tintIcon(host,color)
    for _,line in ipairs(host:GetChildren()) do if line:IsA("Frame") then line.BackgroundColor3=color end end
end
local metallicColors={Color3.fromRGB(39,37,49),Color3.fromRGB(23,22,32),C.black,Color3.fromRGB(25,20,36)}
-- VFX modules share the existing lifecycle and alpha compositor. No downloaded
-- modules, global render bindings, or full-window CanvasGroup render targets.
local VFX={images={},buttons={},reflections={items={},nextAt=5,serial=0}}

-- Shared, built-in cyan accent. One translucent wash and the existing metallic
-- stroke move together; gradients are allocated once, never rebuilt each frame.
-- Independent phases keep navigation, surfaces and the toast from flashing in sync.
local NeonFlow={};NeonFlow.__index=NeonFlow
function NeonFlow.new(parent,name,radius,seed,edge)
    local fill=frame(parent,name,UDim2.fromOffset(1,1),UDim2.new(1,-2,1,-2),Color3.new(1,1,1),1)
    fill.Active=false;fill.ZIndex=3;corner(fill,radius)
    local wash=gradient(fill,{C.deep,C.violet,C.cyan,C.ice,C.deep},26)
    wash.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),
        NumberSequenceKeypoint.new(.2,.75),NumberSequenceKeypoint.new(.48,.04),
        NumberSequenceKeypoint.new(.70,.52),NumberSequenceKeypoint.new(1,1)})
    return setmetatable({fill=fill,wash=wash,edge=edge,seed=seed},NeonFlow)
end
function NeonFlow:update(time,strength)
    local phase=time*.48+self.seed
    self.wash.Offset=Vector2.new(math.sin(phase)*.42,math.cos(phase*.67)*.07)
    self.wash.Rotation=26+math.sin(phase*.73)*8
    if self.edge then
        self.edge.Offset=Vector2.new(math.sin(phase+.8)*.28,0)
        self.edge.Rotation=24+math.sin(phase*.61)*15
    end
    alpha(self.fill,"BackgroundTransparency",1-strength)
end
local function shown(object)
    while object and object~=UI.gui do
        if object:IsA("GuiObject") and not object.Visible then return false end
        object=object.Parent
    end
    return object~=nil
end
local function addReflection(object,light,strength)
    local item={object=object,light=light,strength=strength or .1}
    VFX.reflections.items[#VFX.reflections.items+1]=item
    alpha(object,"BackgroundTransparency",1)
    return item
end
function VFX.reflections:request(item)
    if not item or not shown(item.object) then return end
    if self.active then alpha(self.active.object,"BackgroundTransparency",1) end
    self.active=item;self.elapsed=0;self.nextAt=state.phase+6.5
end
function VFX.reflections:update(dt)
    local item=self.active
    if item then
        self.elapsed+=dt
        local t=math.min(1,self.elapsed/.95)
        if not shown(item.object) or t>=1 then
            alpha(item.object,"BackgroundTransparency",1);self.active=nil
        else
            -- Only ONE diagonal highlight is active, regardless of hover spam.
            item.light.Offset=Vector2.new(-1.15+2.3*t,0)
            alpha(item.object,"BackgroundTransparency",1-math.sin(t*math.pi)^2*item.strength)
        end
    elseif state.phase>=self.nextAt and state.target=="open" then
        self.nextAt=state.phase+7.5
        for _=1,#self.items do
            self.serial=self.serial%#self.items+1
            local candidate=self.items[self.serial]
            if shown(candidate.object) then self:request(candidate);break end
        end
    end
end
local buttons=VFX.buttons
local function updateButtonLight(record)
    local selected=record.selection.Value
    local energy=record.energy.Value
    alpha(record.selectionWash,"BackgroundTransparency",1-selected*.17)
    alpha(record.edge,"Transparency",.58-selected*.32-energy*.18)
    alpha(record.lip,"BackgroundTransparency",.84-selected*.19-energy*.18)
end
local function button(parent,name,pos,size)
    local b=make("TextButton",parent,{Name=name,Text="",Position=pos,Size=size,BackgroundTransparency=1,AutoButtonColor=false,Selectable=true})
    local face=frame(b,"MetalFace",UDim2.fromScale(.5,.5),UDim2.fromScale(1,1),Color3.new(1,1,1))
    face.AnchorPoint=Vector2.new(.5,.5);corner(face,10)
    local scale=make("UIScale",face,{Name="PressScale",Scale=1})
    local wash=gradient(face,metallicColors,108)
    local selectedWash=frame(face,"SelectionWash",UDim2.fromScale(0,0),UDim2.fromScale(1,1),Color3.new(1,1,1),1)
    corner(selectedWash,10);local selectedGradient=gradient(selectedWash,{C.cyan,C.deep,C.violet},110)
    local edge=stroke(face,Color3.new(1,1,1),.58,1)
    local edgeGradient=gradient(edge,{C.steel,C.cyan,C.silver,C.deep,C.violet},34)
    local neon=NeonFlow.new(face,"OptionNeon",9,#buttons*1.17,edgeGradient)
    neon.fill.ZIndex=1
    local lip=frame(face,"MetalLip",UDim2.fromOffset(11,1),UDim2.new(1,-22,0,1),C.chrome,.84)
    local lipGradient=gradient(lip,{C.violet,C.cyan,C.chrome},0);fadeGradient(lipGradient)
    local sheen=frame(face,"Sheen",UDim2.fromOffset(2,2),UDim2.new(1,-4,1,-4),C.white,1)
    corner(sheen,9); local light=gradient(sheen,{C.cyan,C.white,C.light},25); fadeGradient(light)
    lip.ZIndex=2;sheen.ZIndex=2
    local record={button=b,face=face,scale=scale,edge=edge,wash=wash,sheen=sheen,light=light,lip=lip,
        selectionWash=selectedWash,selectedGradient=selectedGradient,neon=neon,hover=false,selected=false,pressed=false,
        energy=make("NumberValue",b,{Name="InteractionLight",Value=0}),
        selection=make("NumberValue",b,{Name="SelectionBlend",Value=0})}
    record.reflection=addReflection(sheen,light,.13)
    buttons[#buttons+1]=record
    connect(record.energy.Changed,function() updateButtonLight(record) end)
    connect(record.selection.Changed,function() updateButtonLight(record) end)
    connect(b.MouseEnter,function() record.hover=true;tween(record.energy,.2,{Value=.65});VFX.reflections:request(record.reflection) end)
    connect(b.MouseLeave,function() record.hover=false;if not record.pressed then tween(record.energy,.28,{Value=0}) end end)
    connect(b.InputBegan,function(input)
        if record.pressed then return end
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            record.pressed=true;record.pointer=input
            tween(scale,.09,{Scale=.977});tween(record.energy,.12,{Value=1})
            VFX.reflections:request(record.reflection)
        end
    end)
    connect(b.Activated,function() VFX.reflections:request(record.reflection) end)
    return b,record
end
local function releaseButtons(input,force)
    for _,record in ipairs(buttons) do
        if record.pressed and (force or input==record.pointer or
            (record.pointer.UserInputType==Enum.UserInputType.MouseButton1 and input.UserInputType==Enum.UserInputType.MouseButton1)) then
            record.pressed=false;record.pointer=nil
            tween(record.scale,.22,{Scale=1});tween(record.energy,.28,{Value=force and 0 or (record.hover and .65 or 0)})
        end
    end
end
connect(Input.InputEnded,function(input) releaseButtons(input,false) end)
connect(Input.WindowFocusReleased,function() releaseButtons(nil,true) end)

local function brandText(parent,name,pos,size,pixels)
    local text=label(parent,name,"Reyzn",pos,size,pixels,C.white,Enum.Font.GrenzeGotisch)
    text.TextColor3=Color3.new(1,1,1)
    text.TextTruncate=Enum.TextTruncate.None
    -- Static chrome bands keep the lettering crisp; only a rare separate sweep
    -- moves. Text stays native and readable even when images cannot be loaded.
    local metal=make("UIGradient",text,{Rotation=90,Color=ColorSequence.new({
        ColorSequenceKeypoint.new(0,C.chrome),ColorSequenceKeypoint.new(.30,C.white),
        ColorSequenceKeypoint.new(.50,C.muted),ColorSequenceKeypoint.new(.57,C.chrome),
        ColorSequenceKeypoint.new(1,C.light)})})
    local outline=make("UIStroke",text,{Color=C.black,Transparency=.28,Thickness=.8,ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual})
    return text,metal,outline
end


UI.gui=make("ScreenGui",playerGui,{Name="ReyznX_Ghislain_VisualOnly",ResetOnSpawn=false,DisplayOrder=50,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,IgnoreGuiInset=false})
pcall(function() UI.gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets end)
UI.gui:SetAttribute("Version",VERSION)
UI.gui:SetAttribute("Build",BUILD)
UI.gui:SetAttribute("ScriptStatus","Visual Only")
UI.gui:SetAttribute("VisualOnly",true)
UI.gui:SetAttribute("OriginalSource","hzReyzn/Ghislain/Reyzn X.lua")
UI.gui:SetAttribute("VisualQuality","Ultra High")
UI.gui:SetAttribute("EffectiveQuality","Ultra High")
UI.gui:SetAttribute("VFXRate",VFX_RATE)
local function cleanup()
    if not state.alive then return end
    state.alive=false; state.drag=nil
    for _,feature in pairs(features) do feature:destroy() end
    for _,c in ipairs(connections) do c:Disconnect() end
    for _,t in pairs(tweens) do t:Cancel() end
    for thread in pairs(threads) do if coroutine.status(thread)~="dead" then pcall(task.cancel,thread) end end
    table.clear(connections);table.clear(threads);table.clear(tweens)
end
connections[#connections+1]=UI.gui.Destroying:Connect(cleanup)
UI.windowFade=make("NumberValue",UI.gui,{Name="WindowOpacity",Value=0})
UI.launcherFade=make("NumberValue",UI.gui,{Name="LauncherOpacity",Value=0})
UI.paneProgress=make("NumberValue",UI.gui,{Name="PaneProgress",Value=1})
UI.pageFade=make("NumberValue",UI.gui,{Name="PageOpacity",Value=1})
UI.zoom=make("NumberValue",UI.gui,{Name="WindowZoom",Value=.985})
UI.screen=frame(UI.gui,"SafeArea",UDim2.fromScale(0,0),UDim2.fromScale(1,1),nil,1)
UI.screen.ClipsDescendants=false
UI.window=frame(UI.screen,"Window",UDim2.fromOffset(100,100),UDim2.fromOffset(880,420),nil,1,"window")
UI.window.ClipsDescendants=false
UI.scale=make("UIScale",UI.window,{Scale=.985})

-- Four shallow light fields are clipped inside each surface. Their edge energy
-- travels independently; no dark shadow extends below the bottom border.
local InwardLight={};InwardLight.__index=InwardLight
function InwardLight.new(parent,seed)
    local self=setmetatable({fields={},seed=seed},InwardLight)
    local clip=frame(parent,"InwardLight",UDim2.fromOffset(2,2),UDim2.new(1,-4,1,-4),nil,1)
    clip.ZIndex=3;clip.ClipsDescendants=true;clip.Active=false
    for side=1,4 do
        local field=frame(clip,"InwardGlow",UDim2.fromScale(0,0),UDim2.fromScale(1,1),nil,1)
        field.Active=false
        local horizontal=side%2==1
        field.Size=horizontal and UDim2.new(.58,0,0,26) or UDim2.new(0,24,.58,0)
        local strips={}
        -- Feather both dimensions: the cross-edge gradient fades inward, while
        -- the strip weights fade both ends. No hard-ended glowing pills.
        for i=1,9 do
            local strip=frame(field,"GlowFeather",horizontal and UDim2.fromScale((i-1)/9,0) or UDim2.fromScale(0,(i-1)/9),
                horizontal and UDim2.fromScale(1/9,1) or UDim2.fromScale(1,1/9),Color3.new(1,1,1),1)
            strip.Active=false
            local wash=gradient(strip,side%2==1 and {C.cyan,C.violet,C.deep} or {C.deep,C.violet,C.cyan},horizontal and 90 or 0)
            local reverse=side==2 or side==3
            wash.Transparency=NumberSequence.new({
                NumberSequenceKeypoint.new(0,reverse and 1 or 0),
                NumberSequenceKeypoint.new(.25,reverse and .96 or .55),
                NumberSequenceKeypoint.new(.75,reverse and .55 or .96),
                NumberSequenceKeypoint.new(1,reverse and 0 or 1)})
            strips[i]={node=strip,weight=math.sin((i-.5)/9*math.pi)^2}
        end
        self.fields[side]={node=field,strips=strips}
    end
    return self
end
function InwardLight:update(time,burst)
    for side,item in ipairs(self.fields) do
        local travel=.21+.19*math.sin(time*.24+self.seed+side*1.7)
        local node=item.node
        if side==1 then node.Position=UDim2.new(travel,0,0,0)
        elseif side==2 then node.Position=UDim2.new(1,-24,travel,0)
        elseif side==3 then node.Position=UDim2.new(travel,0,1,-26)
        else node.Position=UDim2.new(0,0,travel,0) end
        local strength=.21+.06*math.sin(time*.7+self.seed+side)^2+burst*.025
        for _,strip in ipairs(item.strips) do alpha(strip.node,"BackgroundTransparency",1-strength*strip.weight) end
    end
end
local function background(parent,radius)
    local image=imageLabel(parent,"InterfaceBackground",UDim2.fromOffset(1,1),UDim2.new(1,-2,1,-2))
    image.ZIndex=2;image.ScaleType=Enum.ScaleType.Crop;image.Active=false
    image.ImageColor3=Color3.new(1,1,1);corner(image,radius)
    alpha(image,"ImageTransparency",BACKGROUND_TRANSPARENCY)
    artworkImages.Background[#artworkImages.Background+1]=image
    return image
end
-- The supplied emblem remains unchanged. Three low-opacity copies provide a
-- traveling bloom and a narrow highlight; only gradients/alpha move each tick.
local EmblemNeon={};EmblemNeon.__index=EmblemNeon
function EmblemNeon.new(host)
    local self=setmetatable({layers={}},EmblemNeon)
    for i,data in ipairs({{"EmblemBloomWide",16,.40,0},{"EmblemBloomNear",6,.48,.5},{"EmblemSweep",0,.68,0}}) do
        local image=imageLabel(host,data[1],UDim2.fromOffset(-data[2]/2,-data[2]/2),UDim2.new(1,data[2],1,data[2]))
        image.ZIndex=i==3 and 4 or i;image.Active=false
        local wash=gradient(image,{C.pink,C.light,C.violet,C.rose},0)
        if i==3 then
            wash.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.26,1),
                NumberSequenceKeypoint.new(.46,.08),NumberSequenceKeypoint.new(.54,.08),NumberSequenceKeypoint.new(.74,1),NumberSequenceKeypoint.new(1,1)})
        end
        alpha(image,"ImageTransparency",1)
        artworkImages.Emblem[#artworkImages.Emblem+1]=image
        self.layers[i]={image=image,wash=wash,strength=data[3],phase=data[4]}
    end
    return self
end
function EmblemNeon:update(time,burst)
    local tint=C.pink:Lerp(C.orchid,.5+.5*math.sin(time*.8))
    for _,layer in ipairs(self.layers) do
        local progress=(time/4.8+layer.phase)%1
        local envelope=math.sin(progress*math.pi)^2
        layer.wash.Offset=Vector2.new(-.9+1.8*progress,0)
        layer.image.ImageColor3=tint
        alpha(layer.image,"ImageTransparency",1-envelope*(layer.strength+burst*.04))
    end
end
local function surface(parent,name,pos,size,scope)
    local o=frame(parent,name,pos,size,Color3.new(1,1,1),0,scope);corner(o,16)
    gradient(o,{C.panel,C.base,C.black},100)
    background(o,15)
    local inward=InwardLight.new(o,name=="Dock" and .7 or 2.3)
    local edge=stroke(o,Color3.new(1,1,1),.36,1)
    local metal=gradient(edge,{C.steel,C.cyan,C.silver,C.violet,C.black,C.cyan},24)
    local neon=NeonFlow.new(o,"SurfaceNeon",15,name=="Dock" and .45 or 2.8,metal)
    local inner=frame(o,"InnerRim",UDim2.fromOffset(2,2),UDim2.new(1,-4,1,-4),nil,1)
    corner(inner,14);stroke(inner,C.silver,.94,1)
    local beam=frame(o,"EdgeLight",UDim2.fromOffset(16,0),UDim2.new(1,-32,0,1),C.white,.65)
    local beamGradient=gradient(beam,{C.violet,C.cyan,C.silver},0);fadeGradient(beamGradient)
    local sheen=frame(o,"SurfaceReflection",UDim2.fromOffset(3,3),UDim2.new(1,-6,1,-6),C.chrome,1)
    corner(sheen,14);local sweep=gradient(sheen,{C.chrome,C.ice},28);fadeGradient(sweep)
    inner.ZIndex=3;beam.ZIndex=3;sheen.ZIndex=3
    addReflection(sheen,sweep,.035)
    return o,{edge=edge,metal=metal,beam=beam,beamGradient=beamGradient,inward=inward,neon=neon}
end
UI.dock,UI.dockFx=surface(UI.window,"Dock",UDim2.fromOffset(0,0),UDim2.fromOffset(170,420))
UI.dock.ZIndex=2
UI.dockCrown=icon(UI.dock,"crown",UDim2.fromOffset(17,20),24,C.light)
UI.brand=brandText(UI.dock,"BrandText",UDim2.fromOffset(46,8),UDim2.fromOffset(116,44),25)
UI.dragArea=frame(UI.dock,"DragArea",UDim2.fromOffset(0,0),UDim2.new(1,0,0,60),nil,1)
UI.dragArea.Active=true;UI.dragArea.ZIndex=5
UI.dockDivider=frame(UI.dock,"Divider",UDim2.fromOffset(14,62),UDim2.new(1,-28,0,1),C.line,.25)
gradient(UI.dockDivider,{C.black,C.violet,C.black},0)
UI.nav=make("ScrollingFrame",UI.dock,{Name="Navigation",Position=UDim2.fromOffset(9,76),Size=UDim2.new(1,-18,1,-138),
    BackgroundTransparency=1,CanvasSize=UDim2.fromOffset(0,240),CanvasPosition=Vector2.zero,ScrollBarThickness=2,
    ScrollBarImageColor3=C.violet,ScrollBarImageTransparency=.65,Active=true,ScrollingEnabled=true,
    ClipsDescendants=true,ScrollingDirection=Enum.ScrollingDirection.Y,AutomaticCanvasSize=Enum.AutomaticSize.None})
local navigation={}
local optionFont=OPTION_FONT
for i,data in ipairs({{"Home","home"},{"Main","cube"},{"Visuals","spark"},{"Scripts","code"},{"Settings","settings"}}) do
    local b,fx=button(UI.nav,"Tab_"..data[1],UDim2.fromOffset(0,(i-1)*48),UDim2.new(1,-3,0,42))
    local glyph=icon(b,data[2],UDim2.fromOffset(12,10),22,C.muted)
    local caption=label(b,"Caption",data[1],UDim2.fromOffset(45,0),UDim2.new(1,-51,1,0),19,C.muted,optionFont)
    navigation[data[1]]={button=b,fx=fx,icon=glyph,caption=caption,index=i}
end
UI.selectionLight=frame(UI.nav,"SelectionLight",UDim2.fromOffset(0,12),UDim2.fromOffset(2,18),Color3.new(1,1,1),0)
gradient(UI.selectionLight,{C.violet,C.cyan,C.chrome},90)
UI.selectionLight.ZIndex=4;corner(UI.selectionLight,2)
UI.controls=frame(UI.dock,"WindowControls",UDim2.new(0,12,1,-50),UDim2.new(1,-24,0,36),nil,1)
local controlArtwork={}
for i,data in ipairs({{"Minimize","minimize"},{"Collapse","fold"},{"Close","close"}}) do
    local b=make("ImageButton",UI.controls,{Name=data[1],Image="",BackgroundTransparency=1,Position=UDim2.fromOffset((i-1)*46,0),Size=UDim2.fromOffset(40,36),AutoButtonColor=false,Active=true,Selectable=true})
    local fallback=frame(b,"ControlFallback",UDim2.fromScale(0,0),UDim2.fromScale(1,1),Color3.new(1,1,1))
    corner(fallback,10);gradient(fallback,metallicColors,105);stroke(fallback,C.silver,.6)
    local glyph=icon(fallback,data[2],UDim2.fromOffset(9,7),22,C.silver)
    if data[1]=="Collapse" then UI.foldIcon=glyph end
    local glow=imageLabel(b,"ControlGlow",UDim2.fromScale(.5,.5),UDim2.new(1,8,1,6))
    glow.AnchorPoint=Vector2.new(.5,.5);glow.ImageColor3=C.ice;alpha(glow,"ImageTransparency",.95)
    local art=imageLabel(b,"ControlArtwork",UDim2.fromScale(.5,.5),UDim2.new(1,4,1,0))
    art.AnchorPoint=Vector2.new(.5,.5)
    local artScale=make("UIScale",art,{Scale=1})
    local record={image=art,glow=glow,fallback=fallback,glyph=glyph,scale=artScale,pressed=false,hover=false}
    controlArtwork[data[1]]=record
    local controlSheen=frame(b,"ControlReflection",UDim2.fromOffset(2,8),UDim2.new(1,-4,0,20),C.chrome,1)
    corner(controlSheen,8);local controlSweep=gradient(controlSheen,{C.white,C.ice},25);fadeGradient(controlSweep)
    record.reflection=addReflection(controlSheen,controlSweep,.17)
    connect(b.MouseEnter,function() record.hover=true;alpha(glow,"ImageTransparency",.82);VFX.reflections:request(record.reflection);if not record.pressed then tween(artScale,.18,{Scale=1.025}) end end)
    connect(b.MouseLeave,function() record.hover=false;alpha(glow,"ImageTransparency",.95);if not record.pressed then tween(artScale,.18,{Scale=1}) end end)
    connect(b.InputBegan,function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            if record.pressed then return end
            record.pressed=true;record.pointer=input;tween(artScale,.09,{Scale=.97});alpha(glow,"ImageTransparency",.74);VFX.reflections:request(record.reflection)
        end
    end)
    connect(Input.InputEnded,function(input)
        if record.pressed and (input==record.pointer or (record.pointer.UserInputType==Enum.UserInputType.MouseButton1 and input.UserInputType==Enum.UserInputType.MouseButton1)) then
            record.pressed=false;record.pointer=nil;tween(artScale,.22,{Scale=record.hover and 1.025 or 1});alpha(glow,"ImageTransparency",record.hover and .82 or .95)
        end
    end)
    connect(Input.WindowFocusReleased,function() record.pressed=false;record.pointer=nil;tween(artScale,.16,{Scale=1}) end)
    UI[data[1]]=b
end
UI.reveal=frame(UI.window,"PanelReveal",UDim2.fromOffset(180,0),UDim2.fromOffset(700,420),nil,1,"pane")
UI.reveal.ZIndex=2
UI.reveal.ClipsDescendants=true
UI.panel,UI.panelFx=surface(UI.reveal,"Panel",UDim2.fromOffset(4,4),UDim2.fromOffset(692,412))
VFX.surfaces={UI.dockFx,UI.panelFx}
UI.header=frame(UI.panel,"Header",UDim2.fromOffset(20,8),UDim2.new(1,-40,0,58),nil,1)
UI.pageTitle=label(UI.header,"PageTitle","Home",UDim2.fromOffset(0,0),UDim2.fromOffset(130,54),23,C.white,optionFont)
UI.avatarPlate=frame(UI.header,"AvatarPlate",UDim2.fromOffset(190,11),UDim2.fromOffset(32,32),C.panel)
corner(UI.avatarPlate,100);stroke(UI.avatarPlate,C.light,.18)
UI.avatarFallback=label(UI.avatarPlate,"AvatarFallback",string.upper(string.sub(player.Name,1,1)),UDim2.fromScale(0,0),UDim2.fromScale(1,1),14)
UI.avatarFallback.TextXAlignment=Enum.TextXAlignment.Center
UI.avatar=imageLabel(UI.avatarPlate,"Avatar",UDim2.fromOffset(2,2),UDim2.new(1,-4,1,-4))
UI.avatar.ScaleType=Enum.ScaleType.Crop;corner(UI.avatar,100)
UI.userID=label(UI.header,"UserID","ID  "..tostring(player.UserId),UDim2.fromOffset(232,0),UDim2.fromOffset(170,54),12,C.muted)
UI.sessionDot=frame(UI.header,"SessionDot",UDim2.fromOffset(422,24),UDim2.fromOffset(5,5),C.violet)
corner(UI.sessionDot,5)
UI.session=label(UI.header,"SessionTime","00:00:00",UDim2.fromOffset(436,0),UDim2.fromOffset(94,54),12,C.silver,Enum.Font.RobotoMono)
UI.panelDrag=frame(UI.panel,"PanelDragArea",UDim2.fromOffset(0,0),UDim2.new(1,0,0,68),nil,1)
UI.panelDrag.Active=true;UI.panelDrag.ZIndex=5
UI.headerLine=frame(UI.panel,"HeaderLine",UDim2.fromOffset(18,67),UDim2.new(1,-36,0,1),C.line,.2)
gradient(UI.headerLine,{C.steel,C.deep,C.silver},0)
UI.content=frame(UI.panel,"Content",UDim2.fromOffset(16,80),UDim2.new(1,-32,1,-116),nil,1)
UI.content.ClipsDescendants=true
UI.credit=label(UI.panel,"Credit","Made By Reyzn",UDim2.new(0,20,1,-30),UDim2.new(1,-40,0,22),11,C.muted)
UI.credit.TextXAlignment=Enum.TextXAlignment.Right
local pages={}
for _,name in ipairs({"Home","Main","Visuals","Scripts","Settings"}) do
    local page=make("ScrollingFrame",UI.content,{Name="Page_"..name,Position=UDim2.fromOffset(0,0),Size=UDim2.fromScale(1,1),
        BackgroundTransparency=1,CanvasSize=UDim2.fromOffset(0,0),CanvasPosition=Vector2.zero,ScrollBarThickness=3,
        ScrollBarImageColor3=C.violet,ScrollBarImageTransparency=.5,Active=true,ScrollingEnabled=true,
        ClipsDescendants=true,ScrollingDirection=Enum.ScrollingDirection.Y,AutomaticCanvasSize=Enum.AutomaticSize.None,Visible=name=="Home"},"page")
    pages[name]=page
end
-- Main contains opt-in features; the other three work pages remain empty.
-- Visual quality is always Ultra High.
UI.hero=frame(pages.Home,"Hero",UDim2.fromOffset(1,1),UDim2.new(1,-8,0,200),Color3.new(1,1,1))
corner(UI.hero,13)
local heroEdge=stroke(UI.hero,Color3.new(1,1,1),.52)
local heroMetal=gradient(heroEdge,{C.violet,C.cyan,C.silver,C.deep},28)
gradient(UI.hero,{Color3.fromRGB(28,22,40),C.black,Color3.fromRGB(26,17,39)},32)
local heroSheen=frame(UI.hero,"HeroReflection",UDim2.fromOffset(2,2),UDim2.new(1,-4,1,-4),C.chrome,1)
corner(heroSheen,12);local heroSweep=gradient(heroSheen,{C.chrome,C.light},28);fadeGradient(heroSweep)
addReflection(heroSheen,heroSweep,.05)
UI.heroTitle=brandText(UI.hero,"HeroTitle",UDim2.fromOffset(20,10),UDim2.fromOffset(268,100),48)
UI.heroTitle.ZIndex=4
UI.heroBackground=background(UI.hero,12)
UI.heroNeon=NeonFlow.new(UI.hero,"HeroNeon",12,4.6,heroMetal)
heroSheen.ZIndex=3
UI.status=frame(UI.hero,"ScriptInfo",UDim2.fromOffset(22,116),UDim2.fromOffset(188,64),nil,1)
UI.status.ZIndex=4
UI.statusLabel=label(UI.status,"StatusLabel","Status",UDim2.fromOffset(0,0),UDim2.fromOffset(62,26),17,C.muted,optionFont)
UI.statusDot=frame(UI.status,"StatusDot",UDim2.fromOffset(71,11),UDim2.fromOffset(4,4),C.pink,.08)
corner(UI.statusDot,4)
UI.statusValue=label(UI.status,"StatusValue","Preview",UDim2.fromOffset(82,0),UDim2.new(1,-82,0,26),17,C.white,optionFont)
UI.versionLabel=label(UI.status,"VersionLabel","Version",UDim2.fromOffset(0,29),UDim2.fromOffset(62,26),17,C.muted,optionFont)
UI.versionValue=label(UI.status,"VersionValue",VERSION,UDim2.fromOffset(71,29),UDim2.new(1,-71,0,26),16,C.light,Enum.Font.RobotoMono)
UI.emblemHost=frame(UI.hero,"EmblemHost",UDim2.new(1,-224,0,2),UDim2.fromOffset(220,196),nil,1)
UI.emblemHost.ZIndex=4
UI.emblemNeon=EmblemNeon.new(UI.emblemHost)
UI.xFallback=label(UI.emblemHost,"XFallback","X",UDim2.fromScale(0,0),UDim2.fromScale(1,1),92,C.light,Enum.Font.GothamBold)
UI.xFallback.ZIndex=3;UI.xFallback.TextXAlignment=Enum.TextXAlignment.Center
UI.xImage=imageLabel(UI.emblemHost,"EmblemX",UDim2.fromScale(0,0),UDim2.fromScale(1,1))
UI.xImage.ZIndex=3;artworkImages.Emblem[#artworkImages.Emblem+1]=UI.xImage
-- Explicit sibling layers keep supplied backgrounds visible and controls above
-- the decoration, independently of creation order or later asset completion.
for _,object in ipairs({UI.dockCrown,UI.brand,UI.dockDivider,UI.nav,UI.controls,
    UI.header,UI.headerLine,UI.content,UI.credit}) do object.ZIndex=4 end

UI.launcher=make("ImageButton",UI.screen,{Name="Launcher",Image="",BackgroundTransparency=1,Size=UDim2.fromOffset(68,68),Position=UDim2.fromOffset(20,150),AutoButtonColor=false,Visible=false,Selectable=true},"launcher")
UI.launcherScale=make("UIScale",UI.launcher,{Scale=.92})
UI.launcherArt=frame(UI.launcher,"LauncherArtwork",UDim2.fromScale(.5,.5),UDim2.fromScale(1,1),nil,1)
UI.launcherArt.AnchorPoint=Vector2.new(.5,.5);UI.launcherArt.ZIndex=2;UI.launcherArt.Active=false
UI.launcherPress=make("UIScale",UI.launcherArt,{Name="LauncherPressScale",Scale=1})
UI.rFallback=label(UI.launcherArt,"RFallback","R",UDim2.fromScale(0,0),UDim2.fromScale(1,1),34,C.white,Enum.Font.GothamBold)
UI.rFallback.TextXAlignment=Enum.TextXAlignment.Center
UI.launcherImage=imageLabel(UI.launcherArt,"LauncherR",UDim2.fromScale(0,0),UDim2.fromScale(1,1))
UI.launcherImage.ZIndex=2;UI.rFallback.ZIndex=2
-- Display the actual logo, rather than the transparent margins of its file.
-- The original PNG is untouched; the touch/drag target remains 68 x 68.
UI.launcherImage.ImageRectOffset=Vector2.new(88,104)
UI.launcherImage.ImageRectSize=Vector2.new(1080,1040)
UI.launcherShine=imageLabel(UI.launcherArt,"LauncherShine",UDim2.fromScale(0,0),UDim2.fromScale(1,1))
UI.launcherShine.ImageRectOffset=UI.launcherImage.ImageRectOffset
UI.launcherShine.ImageRectSize=UI.launcherImage.ImageRectSize
UI.launcherShine.ZIndex=3;UI.launcherShine.Active=false
alpha(UI.launcherShine,"ImageTransparency",1)
UI.launcherSweep=gradient(UI.launcherShine,{C.ice,C.chrome,C.light},-24)
fadeGradient(UI.launcherSweep)
UI.recovery=make("ImageButton",UI.screen,{Name="Recover",Image="",BackgroundColor3=C.panel,Size=UDim2.fromOffset(40,40),Position=UDim2.new(0,8,.5,-20),AutoButtonColor=false,Visible=false})
corner(UI.recovery,10);stroke(UI.recovery,C.light,.3)
UI.recoveryFallback=label(UI.recovery,"RecoveryFallback","R",UDim2.fromScale(0,0),UDim2.fromScale(1,1),22,C.white,Enum.Font.GothamBold)
UI.recoveryFallback.TextXAlignment=Enum.TextXAlignment.Center
UI.recoveryImage=imageLabel(UI.recovery,"RecoveryR",UDim2.fromScale(0,0),UDim2.fromScale(1,1))

-- Every fire surface shares the approved minimized-logo texture, palette and
-- complementary rising lifetimes. The window profile distributes UPWARD roots
-- along its perimeter; it never rotates flames towards the sides or the bottom.
local function noise(seed) return (math.sin(seed*12.9898+78.233)*43758.5453)%1 end
local UpdraftFire={};UpdraftFire.__index=UpdraftFire
local firePink=Color3.fromRGB(183,48,139)
local firePurple=Color3.fromRGB(151,62,246)
local fireCyan=C.cyan
function UpdraftFire.new(parent,name,scope,width,height,wide,perimeter)
    local host=frame(parent,name,UDim2.fromOffset(0,0),UDim2.fromOffset(width,height),nil,1,scope)
    host.Active=false;host.ClipsDescendants=false;host.ZIndex=0
    local self=setmetatable({host=host,roots={},wisps={},embers={},wide=wide,perimeter=perimeter},UpdraftFire)
    local points={}
    if perimeter then
        for side,count in ipairs(perimeter) do
            for i=1,count do points[#points+1]={side=side,fraction=(i-.5)/count} end
        end
    else
        local count=wide and 12 or 8
        for i=1,count do points[i]={fraction=(i-.5)/count} end
    end
    for i,point in ipairs(points) do
        local seed=i*1.713+(perimeter and #name*.23 or 0)
        local root=frame(host,"UpdraftRoot",UDim2.fromOffset(0,0),UDim2.fromOffset(1,1),nil,1)
        root.Active=false
        local layers={}
        for layer=1,2 do
            local image=imageLabel(root,layer==1 and "UpdraftVeil" or "UpdraftBody",UDim2.fromOffset(0,0),UDim2.fromOffset(1,1))
            image.AnchorPoint=Vector2.new(.5,1);image.ScaleType=Enum.ScaleType.Stretch;image.Active=false
            image.ImageRectOffset=Vector2.new(110,0);image.ImageRectSize=Vector2.new(1040,1254)
            local wash=gradient(image,{firePink:Lerp(C.pink,.35),firePurple,C.light,fireCyan},90)
            wash.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.30),
                NumberSequenceKeypoint.new(.2,.02),NumberSequenceKeypoint.new(.78,0),NumberSequenceKeypoint.new(1,1)})
            alpha(image,"ImageTransparency",1)
            layers[layer]=image;VFX.images[#VFX.images+1]=image
        end
        local core=imageLabel(root,"UpdraftCore",UDim2.fromOffset(0,0),UDim2.fromOffset(1,1))
        core.AnchorPoint=Vector2.new(.5,1);core.ScaleType=Enum.ScaleType.Stretch;core.Active=false
        local coreLight=gradient(core,{firePurple,fireCyan,C.chrome},90)
        coreLight.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.2),
            NumberSequenceKeypoint.new(.35,0),NumberSequenceKeypoint.new(.78,0),NumberSequenceKeypoint.new(1,1)})
        alpha(core,"ImageTransparency",1)
        VFX.images[#VFX.images+1]=core
        self.roots[i]={node=root,layers=layers,core=core,seed=seed,
            fraction=point.fraction,side=point.side,height=.85+noise(seed)*.29}
    end
    for i=1,wide and 8 or 6 do
        local node=imageLabel(host,"RisingWisp",UDim2.fromOffset(0,0),UDim2.fromOffset(1,1))
        node.AnchorPoint=Vector2.new(.5,1);node.ScaleType=Enum.ScaleType.Stretch;node.Active=false
        gradient(node,{firePink,firePurple,fireCyan},90);alpha(node,"ImageTransparency",1)
        VFX.images[#VFX.images+1]=node
        self.wisps[i]={node=node,seed=i*1.391,rate=.53+noise(i)*.17}
    end
    for i=1,8 do
        local node=frame(host,"RisingEmber",UDim2.fromOffset(0,0),UDim2.fromOffset(1.3,3.5),i%2==0 and fireCyan or C.rose,1)
        node.Active=false;node.AnchorPoint=Vector2.new(.5,.5);corner(node,2)
        self.embers[i]={node=node,seed=i*.713,rate=.38+noise(i+6)*.22}
    end
    return self
end
function UpdraftFire:update(time,burst)
    local w,h=self.host.Size.X.Offset,self.host.Size.Y.Offset
    if w<20 or h<20 then return end
    local count=#self.roots
    for _,p in ipairs(self.roots) do
        local baseX=-3+(w+6)*p.fraction
        local baseY=h+2
        local height=(h+(self.wide and 27 or 40))*p.height
        local width=self.wide and (w+14)/count*2 or 47
        if self.perimeter then
            if p.side==1 or p.side==3 then
                baseX=10+(w-20)*p.fraction
                baseY=p.side==1 and 4 or h+13
                width=math.clamp(w/self.perimeter[p.side]*1.4,18,66)
                height=(p.side==1 and 64 or 55)*p.height
            else
                baseX=p.side==2 and w+3 or -3
                baseY=16+(h-24)*p.fraction
                width=38;height=math.clamp(h/self.perimeter[p.side]*1.45,66,92)*p.height
            end
        end
        p.node.Position=UDim2.fromOffset(baseX,baseY)
        for layer,image in ipairs(p.layers) do
            local age=(time*(.61+noise(p.seed)*.18)+p.seed+(layer-1)*.5)%1
            local envelope=math.sin(age*math.pi)^2
            local bend=math.sin(time*2.5+p.seed)*2+math.sin(time*4.3-p.seed)*.7
            image.Position=UDim2.fromOffset(bend+math.sin(age*math.pi)*(layer==1 and -3 or 3),-age*5)
            image.Size=UDim2.fromOffset(width*(1.1-age*.2),height*(.73+age*.53))
            image.Rotation=bend*(layer==1 and -1.5 or 2)
            alpha(image,"ImageTransparency",1-envelope*(.87+burst*.04))
        end
        p.core.Position=UDim2.fromOffset(math.sin(time*3-p.seed)*1.5,0)
        p.core.Size=UDim2.fromOffset(width*.63,height*.76)
        p.core.Rotation=math.sin(time*2.6+p.seed)*3
        alpha(p.core,"ImageTransparency",.64-.12*math.sin(time*3.1+p.seed)^2)
    end
    for _,p in ipairs(self.wisps) do
        local age=(time*p.rate+p.seed)%1
        local envelope=math.sin(age*math.pi)^2
        local x=-5+(w+10)*noise(p.seed)+math.sin(age*4+p.seed)*5*age
        local y=h+8-age*(h+(self.wide and 48 or 65))
        if self.perimeter then
            local side=math.floor(p.seed*10)%3
            if side==0 then y=3-age*60
            else x=side==1 and -8 or w+8;y=h*noise(p.seed+2)-age*62 end
        end
        p.node.Position=UDim2.fromOffset(x,y)
        p.node.Size=UDim2.fromOffset((self.wide and 30 or 22)*(1-age*.38),42+age*13)
        p.node.Rotation=math.sin(time*2+p.seed)*7
        alpha(p.node,"ImageTransparency",1-envelope*.66)
    end
    for _,p in ipairs(self.embers) do
        local age=(time*p.rate+p.seed)%1
        local x=-8+(w+16)*noise(p.seed+4)+math.sin(age*5+p.seed)*4
        local y=h+6-age*(h+54)
        if self.perimeter then
            local side=math.floor(p.seed*10)%3
            if side==0 then y=-8-age*48
            else x=(side==1 and -11 or w+11)+math.sin(age*5+p.seed)*3;y=h*noise(p.seed+5)-age*64 end
        end
        p.node.Position=UDim2.fromOffset(x,y)
        alpha(p.node,"BackgroundTransparency",1-math.sin(age*math.pi)^2*.62)
    end
end
UI.dockAura=UpdraftFire.new(UI.window,"DockAura","window",170,420,true,{4,6,3,6})
UI.panelAura=UpdraftFire.new(UI.window,"PanelAura","pane",692,412,true,{14,6,10,6})
UI.launcherAura=UpdraftFire.new(UI.launcher,"LauncherAura","launcher",68,68,false)

-- One short, independent toast per execution. Its whole surface/aura slides
-- together; the four-second hold starts after the entrance has completed.
local LoadToast={};LoadToast.__index=LoadToast
function LoadToast.new()
    UI.toastProgress=make("NumberValue",UI.gui,{Name="ToastProgress",Value=0})
    local host=frame(UI.screen,"LoadNotification",UDim2.fromOffset(0,0),UDim2.fromOffset(330,90),nil,1,"notification")
    host.AnchorPoint=Vector2.new(1,1);host.ZIndex=12;host.Active=false;host.ClipsDescendants=false
    local face=frame(host,"NotificationFace",UDim2.fromScale(0,0),UDim2.fromScale(1,1),Color3.new(1,1,1),0)
    face.ZIndex=2;face.Active=false;corner(face,14)
    gradient(face,{Color3.fromRGB(19,30,42),C.black,Color3.fromRGB(25,17,34)},26)
    local edge=stroke(face,Color3.new(1,1,1),.40,1)
    local edgeLight=gradient(edge,{C.deep,firePurple,fireCyan,C.chrome,firePink},18)
    local neon=NeonFlow.new(face,"NotificationNeon",13,1.9,edgeLight)
    local badge=frame(face,"SuccessBadge",UDim2.fromOffset(15,27),UDim2.fromOffset(34,34),Color3.new(1,1,1))
    badge.Active=false;badge.ZIndex=4;corner(badge,11)
    gradient(badge,{Color3.fromRGB(29,48,62),Color3.fromRGB(17,16,30)},45)
    local badgeEdge=stroke(badge,C.cyan,.46,1)
    gradient(badgeEdge,{C.violet,C.cyan,C.chrome},35)
    local badgeScale=make("UIScale",badge,{Scale=.94})
    for _,line in ipairs({{12,20,7.1,45},{19.5,17.5,15.6,-50}}) do
        local mark=frame(badge,"SuccessCheck",UDim2.fromOffset(line[1],line[2]),UDim2.fromOffset(line[3],2),C.cyan,0)
        mark.AnchorPoint=Vector2.new(.5,.5);mark.Rotation=line[4];mark.Active=false;corner(mark,2)
    end
    local title=label(face,"NotificationBrand","Reyzn",UDim2.fromOffset(61,11),UDim2.new(1,-78,0,24),19,C.white,Enum.Font.GrenzeGotisch)
    title.Active=false;title.ZIndex=4
    local message=label(face,"NotificationMessage","The script has loaded\nsuccessfully :))",UDim2.fromOffset(61,35),UDim2.new(1,-78,0,43),18,C.silver,OPTION_FONT)
    message.TextWrapped=true;message.TextTruncate=Enum.TextTruncate.None;message.Active=false;message.ZIndex=4
    local glint=frame(face,"NotificationEdgeLight",UDim2.new(.1,0,0,0),UDim2.new(.48,0,0,1),Color3.new(1,1,1),.32)
    glint.Active=false;glint.ZIndex=3
    local glintWash=gradient(glint,{C.violet,C.cyan,C.chrome},0);fadeGradient(glintWash)
    local self=setmetatable({host=host,phase="prepared",progress=UI.toastProgress},LoadToast)
    self.neon=neon;self.badgeScale=badgeScale;self.badgeEdge=badgeEdge;self.glint=glint
    self.fire=UpdraftFire.new(host,"NotificationAura","notification",330,90,true)
    self.connection=connect(self.progress.Changed,function() self:position();refreshAlpha() end)
    self:resize()
    return self
end
function LoadToast:start()
    self.started=os.clock();self.phase="entering"
    UI.gui:SetAttribute("LoadNotification","entering")
    tween(self.progress,.48,{Value=1})
end
function LoadToast:position()
    if self.phase=="done" then return end
    -- The extra 78 px hides even the outermost fire at either end of the slide.
    self.host.Position=UDim2.new(1,-16+(self.width+78)*(1-self.progress.Value),1,-26)
    self.badgeScale.Scale=.94+.06*self.progress.Value
end
function LoadToast:resize()
    if self.phase=="done" then return end
    self.width=math.min(330,math.max(200,UI.screen.AbsoluteSize.X-32))
    self.host.Size=UDim2.fromOffset(self.width,90)
    self.fire.host.Size=self.host.Size
    self:position()
end
function LoadToast:destroy()
    if self.phase=="done" then return end
    self.phase="done";self.connection:Disconnect()
    local removed={[self.host]=true,[self.progress]=true}
    for _,o in ipairs(self.host:GetDescendants()) do removed[o]=true end
    -- Unregister before destroying so future page/opacity changes never write
    -- to expired decoration. Pending asset loads share this same image array.
    for i=#alphaEntries,1,-1 do
        if removed[alphaEntries[i].object] then table.remove(alphaEntries,i) end
    end
    for i=#VFX.images,1,-1 do if removed[VFX.images[i]] then table.remove(VFX.images,i) end end
    for o in pairs(removed) do
        alphaLookup[o]=nil;scopes[o]=nil
        if tweens[o] then tweens[o]:Cancel();tweens[o]=nil end
    end
    self.host:Destroy();self.progress:Destroy();UI.toastProgress=nil
    self.fire=nil;self.neon=nil;self.badgeScale=nil;self.badgeEdge=nil;self.glint=nil;self.host=nil;self.progress=nil
    UI.gui:SetAttribute("LoadNotification","done")
end
function LoadToast:dismiss(seconds)
    if self.phase=="done" then return end
    self.phase="exiting";self.endsAt=os.clock()+seconds
    UI.gui:SetAttribute("LoadNotification","exiting")
    tween(self.progress,seconds,{Value=0})
end
function LoadToast:update(now,time)
    if self.phase=="done" then return end
    local elapsed=now-self.started
    if self.endsAt and now>=self.endsAt then self:destroy();return end
    if elapsed>=4.48 and self.phase~="exiting" then
        self:dismiss(.42)
    elseif elapsed>=.48 and self.phase=="entering" then
        self.phase="holding";UI.gui:SetAttribute("LoadNotification","holding")
    end
    self.fire:update(time,0)
    self.neon:update(time,.17)
    self.glint.Position=UDim2.new(.23+.20*math.sin(time*.65),0,0,0)
    alpha(self.badgeEdge,"Transparency",.42+.08*math.sin(time*1.2)^2)
end
UI.loadToast=LoadToast.new()

-- Reused top-right notice. Screen-owned; five full seconds AFTER the entrance.
-- Original user PNGs stay untinted. Glow copies and three small glints are pooled,
-- update only while visible, and share the existing alpha/Heartbeat lifecycle.
local DisasterToast={};DisasterToast.__index=DisasterToast
local DISASTER_HOLD=5
function DisasterToast.new()
    UI.disasterProgress=make("NumberValue",UI.gui,{Name="DisasterOpacity",Value=0})
    local host=frame(UI.screen,"DisasterNotification",UDim2.fromOffset(0,16),UDim2.fromOffset(318,88),nil,1,"disaster")
    host.AnchorPoint=Vector2.new(1,0);host.ZIndex=20;host.Active=false;host.Visible=false
    local halos={}
    for i=1,2 do
        local halo=frame(host,"DisasterHalo",UDim2.fromOffset(-i*2,-i*2),UDim2.new(1,i*4,1,i*4),nil,1)
        halo.ZIndex=0;halo.Active=false;corner(halo,13+i*2)
        local edge=stroke(halo,Color3.new(1,1,1),i==1 and .80 or .94,i==1 and 1.5 or 2)
        local wash=gradient(edge,{C.deep,C.violet,C.cyan,C.ice,C.rose,C.deep},24)
        fadeGradient(wash);halos[i]=wash
    end
    local face=frame(host,"DisasterFace",UDim2.fromScale(0,0),UDim2.fromScale(1,1),Color3.new(1,1,1))
    face.Active=false;face.ZIndex=2;corner(face,13)
    gradient(face,{Color3.fromRGB(23,28,42),Color3.fromRGB(12,12,19),Color3.fromRGB(27,19,37)},24)
    local edge=stroke(face,Color3.new(1,1,1),.28,1)
    local light=gradient(edge,{C.deep,C.violet,C.cyan,C.chrome,C.rose},22)
    local neon=NeonFlow.new(face,"DisasterNeon",12,7.4,light)
    local badge=frame(face,"DisasterBadge",UDim2.new(0,36,.5,0),UDim2.fromOffset(52,52),nil,1)
    badge.AnchorPoint=Vector2.new(.5,.5);badge.Active=false;badge.ZIndex=4
    local badgeScale=make("UIScale",badge,{Scale=.96})
    local icons={}
    for _,data in ipairs({{"detected","Success",C.cyan}, {"unavailable","Failure",C.pink}})do
        local glow=imageLabel(badge,"Disaster"..data[2].."Glow",UDim2.fromScale(.5,.5),UDim2.fromScale(1.13,1.13))
        glow.AnchorPoint=Vector2.new(.5,.5);glow.ImageColor3=data[3];glow.ZIndex=4;glow.Active=false
        alpha(glow,"ImageTransparency",.86)
        local wash=gradient(glow,{C.pink,C.orchid,C.cyan,C.chrome},20)
        local image=imageLabel(badge,"Disaster"..data[2].."Icon",UDim2.fromScale(.5,.5),UDim2.fromScale(1,1))
        image.AnchorPoint=Vector2.new(.5,.5);image.ImageColor3=Color3.new(1,1,1);image.ZIndex=5;image.Active=false
        -- Native line fallback avoids the unsupported Unicode/tofu square in the old toast.
        local fallback=frame(badge,"Disaster"..data[2].."Fallback",UDim2.fromScale(0,0),UDim2.fromScale(1,1),nil,1)
        fallback.ZIndex=3;fallback.Active=false
        local segments=data[1]=="detected" and {{12,26,21,34},{21,34,39,15}} or {{16,16,36,36},{36,16,16,36}}
        for _,p in ipairs(segments)do
            local dx,dy=p[3]-p[1],p[4]-p[2]
            local line=frame(fallback,"Mark",UDim2.fromOffset((p[1]+p[3])/2,(p[2]+p[4])/2),
                UDim2.fromOffset(math.sqrt(dx*dx+dy*dy),2.5),data[3],0)
            line.AnchorPoint=Vector2.new(.5,.5);line.Rotation=math.deg(math.atan2(dy,dx));line.Active=false;corner(line,2)
        end
        icons[data[1]]={image=image,glow=glow,wash=wash,fallback=fallback,asset="Disaster"..data[2]}
    end
    local glints={}
    for i=1,3 do
        local glint=frame(badge,"DisasterIconGlint",UDim2.fromOffset(0,0),UDim2.fromOffset(i==1 and 3 or 2,i==1 and 3 or 2),
            i==1 and C.chrome or i==2 and C.cyan or C.pink,1)
        glint.AnchorPoint=Vector2.new(.5,.5);glint.Rotation=45;glint.Active=false;glint.ZIndex=6;corner(glint,1)
        glints[i]=glint
    end
    local title=label(face,"DisasterTitle","Disaster Detected!",UDim2.fromOffset(72,11),UDim2.new(1,-86,0,23),19,C.white,OPTION_FONT)
    title.ZIndex=4;title.Active=false
    local message=label(face,"DisasterMessage","",UDim2.fromOffset(72,35),UDim2.new(1,-86,0,37),18,C.silver,OPTION_FONT)
    message.TextWrapped=true;message.TextTruncate=Enum.TextTruncate.None;message.ZIndex=4;message.Active=false
    message.TextScaled=true
    make("UITextSizeConstraint",message,{MinTextSize=14,MaxTextSize=18})
    local rail=frame(face,"DisasterTimerRail",UDim2.new(0,14,1,-7),UDim2.new(1,-28,0,1),C.steel,.80)
    rail.Active=false;rail.ZIndex=4;corner(rail,2)
    local bar=frame(rail,"DisasterTimer",UDim2.fromScale(0,0),UDim2.fromScale(1,1),Color3.new(1,1,1),.16)
    bar.Active=false;corner(bar,2);gradient(bar,{C.pink,C.violet,C.cyan},0)
    local glint=frame(face,"DisasterGlint",UDim2.new(.15,0,0,0),UDim2.new(.52,0,0,1),Color3.new(1,1,1),.28)
    glint.Active=false;glint.ZIndex=4;fadeGradient(gradient(glint,{C.deep,C.cyan,C.chrome,C.violet},0))
    local self=setmetatable({host=host,progress=UI.disasterProgress,phase="hidden",halos=halos,icons=icons,
        badgeScale=badgeScale,iconGlints=glints,neon=neon,title=title,message=message,bar=bar,glint=glint},DisasterToast)
    connect(self.progress.Changed,function()self:position();refreshAlpha()end)
    self:resize();self:refreshIcons()
    UI.gui:SetAttribute("DisasterNotification","hidden");UI.gui:SetAttribute("DisasterNoticeCount",0)
    UI.gui:SetAttribute("DisasterNoticeDuration",DISASTER_HOLD)
    UI.gui:SetAttribute("DisasterNoticeLayout","compact-icons-v2")
    return self
end
function DisasterToast:refreshIcons()
    local selected=self.kind=="detected" and "detected" or "unavailable"
    for key,art in pairs(self.icons)do
        local assigned=art.image.Image~=""
        local ready=assigned and art.image.IsLoaded
        -- PreloadAsync can cache hidden textures without uploading them for
        -- rendering. Never make Visible depend on IsLoaded: that deadlocks
        -- the first display on those clients. Keep the native mark underneath.
        art.image.Visible=key==selected and assigned
        art.glow.Visible=key==selected and assigned
        art.fallback.Visible=key==selected and not ready
        if ready then UI.gui:SetAttribute("Asset"..art.asset,"ready")end
    end
end
function DisasterToast:position()
    self.host.Position=UDim2.new(1,-16+(self.width+44)*(1-self.progress.Value),0,16)
    self.badgeScale.Scale=.96+.04*self.progress.Value
end
function DisasterToast:resize()
    self.width=math.max(200,math.min(318,UI.screen.AbsoluteSize.X-32))
    self.host.Size=UDim2.fromOffset(self.width,88);self:position()
end
function DisasterToast:show(kind,text,heading)
    if not state.alive or state.target=="closed" then return end
    self.kind=kind;self.message.Text=text
    self.title.Text=heading or (kind=="detected" and "Disaster Detected!" or "Disaster Prediction")
    self:refreshIcons()
    self.host.Visible=true;self.phase="entering";self.holdAt=os.clock()+.36;self.endsAt=self.holdAt+DISASTER_HOLD;self.exitAt=nil
    self.bar.Size=UDim2.fromScale(1,1)
    UI.gui:SetAttribute("DisasterNoticeText",text);UI.gui:SetAttribute("DisasterNoticeKind",kind)
    UI.gui:SetAttribute("DisasterNoticeCount",UI.gui:GetAttribute("DisasterNoticeCount")+1)
    UI.gui:SetAttribute("DisasterNotification","entering")
    tween(self.progress,.36,{Value=1})
end
function DisasterToast:dismiss(seconds)
    if self.phase=="hidden" then return end
    seconds=seconds or .28
    self.phase="exiting";self.exitAt=os.clock()+seconds
    UI.gui:SetAttribute("DisasterNotification","exiting")
    tween(self.progress,seconds,{Value=0})
end
function DisasterToast:update(now,time)
    if self.phase=="hidden" then return end
    if self.phase=="entering" and now>=self.holdAt then
        self.phase="holding";UI.gui:SetAttribute("DisasterNotification","holding")
    end
    if self.phase=="holding" then
        self.bar.Size=UDim2.fromScale(math.clamp((self.endsAt-now)/DISASTER_HOLD,0,1),1)
        if now>=self.endsAt then self:dismiss(.32)end
    elseif self.phase=="exiting" and now>=self.exitAt then
        self.phase="hidden";self.host.Visible=false;UI.gui:SetAttribute("DisasterNotification","hidden");return
    end
    self.neon:update(time,.13)
    for i,wash in ipairs(self.halos)do wash.Offset=Vector2.new(math.sin(time*.55+i)*.32,0)end
    self.glint.Position=UDim2.new(.17+.17*math.sin(time*.65),0,0,0)
    local art=self.icons[self.kind=="detected" and "detected" or "unavailable"]
    art.wash.Offset=Vector2.new(math.sin(time*.85)*.28,0)
    alpha(art.glow,"ImageTransparency",.86-.045*math.sin(time*1.8)^2)
    for i,spark in ipairs(self.iconGlints)do
        local phase=time*.35+i*2.1
        spark.Position=UDim2.new(.5,math.cos(phase)*28,.5,math.sin(phase)*27)
        alpha(spark,"BackgroundTransparency",1-(.5+.5*math.sin(time*1.7+i*2.3))^4*.68)
    end
end
UI.disasterToast=DisasterToast.new()

-- Compact, reusable feature control. Its hit target never scales; only the
-- inner face compresses. OFF has no colored glow, flash or running light sweep.
local FeatureToggle={};FeatureToggle.__index=FeatureToggle
function FeatureToggle.new(parent,name,title,controller)
    local b=make("TextButton",parent,{Name=name,Text="",Position=UDim2.fromOffset(5,6),
        Size=UDim2.fromOffset(340,60),BackgroundTransparency=1,AutoButtonColor=false,Active=true,Selectable=true})
    local face=frame(b,"ToggleFace",UDim2.fromScale(.5,.5),UDim2.fromScale(1,1),Color3.new(1,1,1))
    face.AnchorPoint=Vector2.new(.5,.5);corner(face,13)
    gradient(face,{Color3.fromRGB(25,26,32),C.black,Color3.fromRGB(21,21,27)},26)
    local scale=make("UIScale",face,{Name="TogglePressScale",Scale=1})
    local glow=frame(b,"ToggleGlow",UDim2.fromOffset(-2,-2),UDim2.new(1,4,1,4),nil,1)
    glow.Active=false;glow.ZIndex=0;corner(glow,15)
    local glowEdge=stroke(glow,Color3.new(1,1,1),1,3)
    local glowLight=gradient(glowEdge,{C.deep,C.violet,C.cyan,C.chrome,C.deep},24)
    fadeGradient(glowLight)
    local activeFace=frame(face,"ToggleActiveSurface",UDim2.fromScale(0,0),UDim2.fromScale(1,1),Color3.new(1,1,1),1)
    activeFace.Active=false;corner(activeFace,13)
    gradient(activeFace,{Color3.fromRGB(19,30,42),C.black,Color3.fromRGB(25,17,34)},26)
    local edge=stroke(face,C.steel,.64,1)
    local edgeLight=gradient(edge,{C.deep,C.violet,C.cyan,C.chrome,C.rose},18)
    edgeLight.Enabled=false
    local neon=NeonFlow.new(face,"ToggleNeon",12,3.4,edgeLight)
    local caption=label(face,"ToggleCaption",title,UDim2.fromOffset(16,0),UDim2.new(1,-104,1,0),20,C.muted,OPTION_FONT)
    caption.Active=false;caption.ZIndex=4;caption.TextTruncate=Enum.TextTruncate.None
    local pill=frame(face,"TogglePill",UDim2.new(1,-14,.5,0),UDim2.fromOffset(62,28),C.black)
    pill.AnchorPoint=Vector2.new(1,.5);pill.Active=false;pill.ZIndex=4;corner(pill,9)
    local pillEdge=stroke(pill,C.steel,.65,1)
    local dot=frame(pill,"ToggleDot",UDim2.fromOffset(10,12),UDim2.fromOffset(4,4),C.steel)
    dot.Active=false;corner(dot,4)
    local status=label(pill,"ToggleStatus","OFF",UDim2.fromOffset(20,0),UDim2.new(1,-24,1,0),17,C.muted,OPTION_FONT)
    status.Active=false;status.TextXAlignment=Enum.TextXAlignment.Center
    local flash=frame(face,"ToggleFlash",UDim2.fromOffset(1,1),UDim2.new(1,-2,1,-2),Color3.new(1,1,1),1)
    flash.Active=false;flash.ZIndex=3;corner(flash,12)
    local flashLight=gradient(flash,{C.violet,C.cyan,C.chrome,C.cyan},24);fadeGradient(flashLight)
    local lip=frame(face,"ToggleEdgeLight",UDim2.fromOffset(12,0),UDim2.new(1,-24,0,1),Color3.new(1,1,1),1)
    lip.Active=false;lip.ZIndex=3
    local lipLight=gradient(lip,{C.violet,C.cyan,C.chrome},0);fadeGradient(lipLight)
    local self=setmetatable({button=b,face=face,controller=controller,attribute=name.."Enabled",scale=scale,activeFace=activeFace,
        caption=caption,pill=pill,pillEdge=pillEdge,dot=dot,status=status,edge=edge,edgeLight=edgeLight,
        glowEdge=glowEdge,glowLight=glowLight,neon=neon,flash=flash,flashLight=flashLight,lip=lip,lipLight=lipLight,
        blend=make("NumberValue",b,{Name="ToggleBlend",Value=0}),
        flashAmount=make("NumberValue",b,{Name="ToggleFlashAmount",Value=0})},FeatureToggle)
    connect(self.blend.Changed,function() self:paint() end)
    connect(self.flashAmount.Changed,function() self:paint() end)
    connect(b.InputBegan,function(input)
        if self.pointer or state.target=="closed" then return end
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            self.pointer=input;tween(scale,.09,{Scale=.978})
        end
    end)
    connect(Input.InputEnded,function(input)
        if self.pointer and (input==self.pointer or (self.pointer.UserInputType==Enum.UserInputType.MouseButton1
            and input.UserInputType==Enum.UserInputType.MouseButton1)) then
            self.pointer=nil;tween(scale,.22,{Scale=1})
        end
    end)
    connect(Input.WindowFocusReleased,function() self.pointer=nil;tween(scale,.18,{Scale=1}) end)
    connect(b.Activated,function()
        if state.target=="closed" then return end
        self:setEnabled(not controller.enabled)
        scale.Scale=.978;tween(scale,.24,{Scale=1})
    end)
    b:SetAttribute("Enabled",false);UI.gui:SetAttribute(self.attribute,false);self:paint()
    return self
end
function FeatureToggle:paint()
    local blend=self.blend.Value
    self.caption.TextColor3=C.muted:Lerp(C.white,blend)
    self.status.TextColor3=C.muted:Lerp(C.cyan,blend)
    self.dot.BackgroundColor3=C.steel:Lerp(C.cyan,blend)
    self.pill.BackgroundColor3=C.black:Lerp(Color3.fromRGB(18,34,46),blend)
    self.pillEdge.Color=C.steel:Lerp(C.cyan,blend)
    self.edge.Color=C.steel:Lerp(Color3.new(1,1,1),blend)
    self.edgeLight.Enabled=blend>.001
    alpha(self.edge,"Transparency",.64-blend*.32)
    alpha(self.pillEdge,"Transparency",.65-blend*.25)
    alpha(self.activeFace,"BackgroundTransparency",1-blend)
    alpha(self.neon.fill,"BackgroundTransparency",1-blend*.20)
    alpha(self.glowEdge,"Transparency",1-blend*.30)
    alpha(self.lip,"BackgroundTransparency",1-blend*.57)
    alpha(self.flash,"BackgroundTransparency",1-self.flashAmount.Value*.36)
end
function FeatureToggle:setEnabled(enabled)
    local actual=self.controller:setEnabled(enabled)
    self.button:SetAttribute("Enabled",actual)
    UI.gui:SetAttribute(self.attribute,actual)
    self.status.Text=actual and "ON" or "OFF"
    tween(self.blend,.26,{Value=actual and 1 or 0})
    if tweens[self.flashAmount] then tweens[self.flashAmount]:Cancel();tweens[self.flashAmount]=nil end
    self.flashAmount.Value=actual and 1 or 0
    if actual then tween(self.flashAmount,.65,{Value=0}) end
end
function FeatureToggle:resize(width)
    local w=math.min(340,math.max(96,width-16))
    local compact=w<248
    self.button.Size=UDim2.fromOffset(w,compact and 88 or 60)
    self.caption.Position=UDim2.fromOffset(compact and 12 or 16,compact and 3 or 0)
    self.caption.Size=compact and UDim2.new(1,-24,0,42) or UDim2.new(1,-104,1,0)
    self.caption.TextSize=compact and 18 or 20;self.caption.TextWrapped=compact
    self.pill.AnchorPoint=Vector2.new(1,compact and 1 or .5)
    self.pill.Position=compact and UDim2.new(1,-12,1,-10) or UDim2.new(1,-14,.5,0)
end
function FeatureToggle:update(time)
    if self.blend.Value<=.001 then return end
    self.neon:update(time,self.blend.Value*.20)
    self.glowLight.Offset=self.neon.wash.Offset
    self.glowLight.Rotation=self.neon.wash.Rotation
    self.lipLight.Offset=Vector2.new(math.sin(time*.65)*.30,0)
    self.flashLight.Offset=Vector2.new((1-self.flashAmount.Value)*1.5-.75,0)
end

UI.mainColumns=frame(pages.Main,"MainColumns",UDim2.fromOffset(0,0),UDim2.fromOffset(600,120),nil,1)
UI.mainLeft=frame(UI.mainColumns,"ToggleOptions",UDim2.fromOffset(0,0),UDim2.fromOffset(288,120),nil,1)
UI.mainRight=frame(UI.mainColumns,"ExecutableOptions",UDim2.fromOffset(312,0),UDim2.fromOffset(288,120),nil,1)
UI.mainDivider=frame(UI.mainColumns,"MainSeparator",UDim2.fromOffset(300,6),UDim2.fromOffset(1,110),C.silver,.88)
UI.mainDivider.Active=false
local mainDividerFade=gradient(UI.mainDivider,{C.steel,C.silver,C.steel},90)
mainDividerFade.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),
    NumberSequenceKeypoint.new(.18,.2),NumberSequenceKeypoint.new(.82,.2),NumberSequenceKeypoint.new(1,1)})


-- ===== VISUAL-ONLY CONTROLS. No gameplay feature modules are loaded. =====
-- The original toggle design and click micro-animations are retained.
local function visualController(whenChanged)
    local controller={enabled=false}
    function controller:setEnabled(value)
        self.enabled=value==true
        if whenChanged then whenChanged(self.enabled) end
        return self.enabled
    end
    function controller:destroy() self.enabled=false end
    return controller
end

features.noFallDamage=visualController()
features.walkOnWater=visualController()
features.antifling=visualController()
features.disasterPrediction=visualController()

UI.noFallToggle=FeatureToggle.new(UI.mainLeft,"NoFallDamage","No Fall Damage",features.noFallDamage)
UI.waterToggle=FeatureToggle.new(UI.mainLeft,"WalkOnWater","Walk on Water",features.walkOnWater)
UI.antiflingToggle=FeatureToggle.new(UI.mainLeft,"Antifling","Antifling",features.antifling)
UI.disasterToggle=FeatureToggle.new(UI.mainLeft,"DisasterPrediction","Disaster Prediction",features.disasterPrediction)
UI.featureToggles={UI.noFallToggle,UI.waterToggle,UI.antiflingToggle,UI.disasterToggle}
UI.gui:SetAttribute("NoFallDamageSupported",false)

UI.disasterManual,UI.disasterManualFX=button(UI.mainLeft,"DisasterPredictionManual",UDim2.fromOffset(5,294),UDim2.fromOffset(272,52))
UI.disasterManual.Active=true
UI.disasterManualCaption=label(UI.disasterManual,"ManualCaption","Predict Disaster",UDim2.fromOffset(12,0),UDim2.new(1,-54,1,0),20,C.white,OPTION_FONT)
UI.disasterManualCaption.TextWrapped=true;UI.disasterManualCaption.Active=false;UI.disasterManualCaption.ZIndex=4
UI.disasterCooldown=label(UI.disasterManual,"ManualCooldown","",UDim2.new(1,-40,0,0),UDim2.fromOffset(30,52),18,C.cyan,OPTION_FONT)
UI.disasterCooldown.Active=false;UI.disasterCooldown.ZIndex=4;UI.disasterCooldown.TextXAlignment=Enum.TextXAlignment.Center
UI.disasterManual:SetAttribute("CooldownRemaining",0)
local function updateDisasterManual() end -- Visual placeholder, no prediction checks
connect(UI.disasterManual.Activated,function()
    state.burst=.7
    UI.disasterManualFX.scale.Scale=.977
    tween(UI.disasterManualFX.scale,.22,{Scale=1})
end)

UI.flyButton,UI.flyButtonFX=button(UI.mainRight,"FlySS3FE",UDim2.fromOffset(5,6),UDim2.fromOffset(272,60))
UI.flyButton.Active=true
UI.flyCaption=label(UI.flyButton,"ExecutableCaption","FLY SS3 FE",UDim2.fromOffset(14,0),UDim2.new(1,-28,1,0),20,C.white,OPTION_FONT)
UI.flyCaption.TextXAlignment=Enum.TextXAlignment.Center
UI.flyCaption.TextWrapped=true;UI.flyCaption.Active=false
UI.flyButton:SetAttribute("ExecutableState","preview")
connect(UI.flyButton.Activated,function() state.burst=.7 end)

UI.mainActions={}
local function actionButton(parent,name,title)
    local b,fx=button(parent,name,UDim2.fromOffset(5,6),UDim2.fromOffset(272,60))
    b.Active=true;b:SetAttribute("ExecutableState","preview")
    local caption=label(b,"ExecutableCaption",title,UDim2.fromOffset(14,0),UDim2.new(1,-28,1,0),20,C.white,OPTION_FONT)
    caption.TextXAlignment=Enum.TextXAlignment.Center;caption.TextWrapped=true;caption.Active=false
    connect(b.Activated,function()
        state.burst=.7
        fx.scale.Scale=.977
        tween(fx.scale,.22,{Scale=1})
    end)
    return {button=b,caption=caption}
end
for _,data in ipairs({
    {"TeleportIsland","Teleport island"},{"TeleportTower","Teleport Tower"}
})do
    UI.mainActions[#UI.mainActions+1]=actionButton(UI.mainRight,data[1],data[2])
end

-- Original FPS panel artwork and visual overlay; this preview never samples FPS.
UI.fpsProgress=make("NumberValue",UI.gui,{Name="FPSOpacity",Value=0})
UI.fpsHost=frame(UI.screen,"FPSOverlay",UDim2.fromOffset(12,12),UDim2.fromOffset(300,100),nil,1,"fps")
UI.fpsHost.ZIndex=22;UI.fpsHost.Active=true;UI.fpsHost.Visible=false
UI.fpsFallback=frame(UI.fpsHost,"FPSFallback",UDim2.fromScale(.03,.16),UDim2.fromScale(.93,.68),C.base,.03)
UI.fpsFallback.Active=false;corner(UI.fpsFallback,12);stroke(UI.fpsFallback,C.violet,.35,1)
local fpsFallbackTitle=label(UI.fpsFallback,"FPSCaption","FPS",UDim2.fromScale(.16,0),UDim2.fromScale(.28,1),25,C.silver,OPTION_FONT)
fpsFallbackTitle.Active=false;fpsFallbackTitle.TextXAlignment=Enum.TextXAlignment.Center
UI.fpsImage=imageLabel(UI.fpsHost,"FPSArtwork",UDim2.fromScale(0,0),UDim2.fromScale(1,1))
UI.fpsImage.ZIndex=2;UI.fpsImage.Active=false
UI.fpsValue=label(UI.fpsHost,"FPSValue","--",UDim2.fromScale(.51,.35),UDim2.fromScale(.39,.30),32,C.chrome,Enum.Font.RobotoMono)
UI.fpsValue.ZIndex=3;UI.fpsValue.Active=false;UI.fpsValue.TextXAlignment=Enum.TextXAlignment.Center
UI.fpsValue.TextScaled=true;UI.fpsValue.TextTruncate=Enum.TextTruncate.None
make("UITextSizeConstraint",UI.fpsValue,{MinTextSize=10,MaxTextSize=34})
connect(UI.fpsProgress.Changed,function()
    refreshAlpha()
    if UI.fpsProgress.Value==0 then UI.fpsHost.Visible=false end
end)
features.fpsCounter=visualController(function(enabled)
    if enabled then UI.fpsHost.Visible=true end
    tween(UI.fpsProgress,.18,{Value=enabled and 1 or 0})
end)
UI.settingsList=frame(pages.Settings,"SettingsOptions",UDim2.fromOffset(0,0),UDim2.fromOffset(350,300),nil,1)
UI.fpsToggle=FeatureToggle.new(UI.settingsList,"FPSCounter","FPS COUNTER",features.fpsCounter)
UI.serverActions={}
features.serverTravel=visualController()
UI.gui:SetAttribute("ServerTravelState","preview")
for _,data in ipairs({
    {"RejoinServer","Rejoin Server"},
    {"ServerHop","Server Hop"},
    {"ServerHopFewPlayers","Server Hop Few players"},
})do
    UI.serverActions[#UI.serverActions+1]=actionButton(UI.settingsList,data[1],data[2])
end

-- Source-matched 'Scripts' buttons, intentionally WITHOUT any script URL or launcher.
UI.scriptList=frame(pages.Scripts,"ScriptExecutables",UDim2.fromOffset(0,0),UDim2.fromOffset(350,150),nil,1)
UI.scriptExecutables={}
for _,data in ipairs({
    {"TelekinesisUI","Telekinesis UI"},
    {"SuperBlackHole","Super Black Hole"},
})do
    local index=#UI.scriptExecutables+1
    local b,fx=button(UI.scriptList,data[1],UDim2.fromOffset(5,6+(index-1)*74),UDim2.fromOffset(340,60))
    b.Active=true;b:SetAttribute("ExecutableState","preview")
    local caption=label(b,"ExecutableCaption",data[2],UDim2.fromOffset(14,0),UDim2.new(1,-28,1,0),20,C.white,OPTION_FONT)
    caption.TextXAlignment=Enum.TextXAlignment.Center;caption.TextWrapped=true;caption.Active=false
    connect(b.Activated,function()
        state.burst=.7
        fx.scale.Scale=.977
        tween(fx.scale,.22,{Scale=1})
    end)
    UI.scriptExecutables[index]={button=b,caption=caption}
end
-- ===== END VISUAL-ONLY CONTROLS =====


-- Put the existing labels/icons inside the press surface, while the original
-- TextButton's touch/click rectangle remains stationary and full-sized.
for _,record in ipairs(buttons) do
    for _,child in ipairs(record.button:GetChildren()) do
        if child:IsA("GuiObject") and child~=record.face then child.Parent=record.face;child.ZIndex=4 end
    end
end

local layout={}
local function applyPane()
    if not layout.width then return end
    local p=UI.paneProgress.Value
    UI.reveal.Size=UDim2.fromOffset(layout.panelWidth*p,layout.height)
    UI.reveal.Visible=p>.001
    UI.window.Size=UDim2.fromOffset(layout.dockWidth+(layout.gap+layout.panelWidth)*p,layout.height)
    UI.panel.Position=UDim2.fromOffset(4-12*(1-p),4)
    UI.panelAura.host.Position=UDim2.fromOffset(layout.dockWidth+layout.gap+4,4)
    UI.panelAura.host.Size=UDim2.fromOffset(math.max(0,layout.panelWidth*p-8),layout.height-8)
    UI.panelAura.host.Visible=p>.03
    UI.foldIcon.Rotation=180*(1-p)
    UI.selectionLight.Visible=state.paneOpen
    refreshAlpha()
end
local function applyPage()
    pages[state.page].Position=UDim2.fromOffset(-8*(1-UI.pageFade.Value),0)
    refreshAlpha()
end
local function recenter()
    local v=UI.screen.AbsoluteSize
    UI.window.Position=UDim2.fromOffset(math.floor((v.X-UI.window.Size.X.Offset)/2),math.floor((v.Y-layout.height)/2))
    UI.launcher.Position=UDim2.fromOffset(18,math.max(12,math.floor(v.Y*.5-34)))
end
local function resize(initial)
    local v=UI.screen.AbsoluteSize
    if v.X<1 or v.Y<1 then return end
    UI.loadToast:resize()
    UI.disasterToast:resize()
    local fpsWidth=math.min(300,math.max(180,v.X-24))
    UI.fpsHost.Size=UDim2.fromOffset(fpsWidth,fpsWidth/3)
    layout.width=math.min(880,math.floor(v.X*(v.X<600 and .94 or .86)))
    layout.height=math.min(420,math.floor(v.Y*.82))
    layout.dockWidth=v.X<320 and 110 or (v.X<600 and 126 or 170)
    layout.gap=8;layout.panelWidth=math.max(150,layout.width-layout.dockWidth-layout.gap)
    local dw,h=layout.dockWidth,layout.height
    UI.dock.Size=UDim2.fromOffset(dw,h)
    UI.dockAura.host.Size=UDim2.fromOffset(dw,h)
    UI.dockCrown.Visible=dw>=150
    UI.brand.Position=UDim2.fromOffset(dw>=150 and 46 or 8,8)
    UI.brand.Size=UDim2.fromOffset(dw-(dw>=150 and 52 or 16),44)
    UI.brand.TextSize=dw>=150 and 25 or (dw<120 and 22 or 24)
    local top=h<320 and 58 or 76
    UI.dockDivider.Position=UDim2.fromOffset(14,top-12)
    UI.dragArea.Size=UDim2.new(1,0,0,top-12)
    UI.nav.Position=UDim2.fromOffset(9,top)
    local available=h-top-60
    local step=math.clamp(math.floor(available/5),30,50)
    UI.nav.Size=UDim2.new(1,-18,0,available)
    UI.nav.CanvasSize=UDim2.fromOffset(0,5*step)
    layout.navStep=step
    for _,n in pairs(navigation) do
        n.button.Position=UDim2.fromOffset(0,(n.index-1)*step)
        n.button.Size=UDim2.new(1,-3,0,step-5)
        n.icon.Position=UDim2.fromOffset(dw>=150 and 12 or 8,(step-5-20)/2)
        n.icon.Visible=dw>=120
        n.caption.Position=UDim2.fromOffset(dw>=150 and 45 or (dw<120 and 12 or 36),0)
        n.caption.Size=UDim2.new(1,dw>=150 and -51 or (dw<120 and -20 or -39),1,0)
        n.caption.TextSize=dw>=150 and 19 or 17
    end
    UI.selectionLight.Position=UDim2.fromOffset(0,(navigation[state.page].index-1)*step+(step-23)/2)
    local controlW=math.floor((dw-24-12)/3)
    UI.controls.Size=UDim2.fromOffset(dw-24,36)
    for i,name in ipairs({"Minimize","Collapse","Close"}) do
        UI[name].Position=UDim2.fromOffset((i-1)*(controlW+6),0);UI[name].Size=UDim2.fromOffset(controlW,36)
        controlArtwork[name].glyph.Position=UDim2.fromOffset((controlW-22)/2,7)
    end
    UI.reveal.Position=UDim2.fromOffset(dw+layout.gap,0)
    local pw=layout.panelWidth-8
    UI.panel.Size=UDim2.fromOffset(pw,h-8)
    local wide=pw>=440
    local headerH=wide and 66 or (pw>=310 and 92 or 114)
    UI.header.Size=UDim2.new(1,-32,0,headerH)
    UI.header.Position=UDim2.fromOffset(16,0)
    UI.pageTitle.Position=UDim2.fromOffset(0,wide and 6 or 4)
    UI.pageTitle.Size=UDim2.fromOffset(wide and (pw>=570 and 116 or 80) or pw-32,wide and 54 or 36)
    local profileY=wide and 17 or 44
    local profileX=wide and (pw>=570 and 132 or 96) or 0
    UI.avatarPlate.Position=UDim2.fromOffset(profileX,profileY)
    UI.avatarPlate.Visible=pw>=160
    UI.userID.Position=UDim2.fromOffset(profileX+41,profileY)
    UI.userID.Size=UDim2.fromOffset(wide and pw-32-profileX-41-110 or math.max(84,pw-78),32)
    UI.sessionDot.Position=UDim2.fromOffset(wide and pw-136 or (pw>=310 and pw-136 or 4),wide and 30 or (pw>=310 and 57 or 89))
    UI.session.Position=UDim2.fromOffset(wide and pw-122 or (pw>=310 and pw-122 or 17),wide and 17 or (pw>=310 and 44 or 76))
    UI.session.Size=UDim2.fromOffset(94,32)
    if not wide and pw>=310 then UI.userID.Size=UDim2.fromOffset(pw-196,32) end
    if pw<160 then UI.userID.Position=UDim2.fromOffset(0,profileY);UI.userID.Size=UDim2.fromOffset(pw-32,32) end
    UI.panelDrag.Size=UDim2.new(1,0,0,headerH)
    UI.headerLine.Position=UDim2.fromOffset(16,headerH)
    UI.content.Position=UDim2.fromOffset(12,headerH+12)
    UI.content.Size=UDim2.new(1,-24,1,-headerH-48)
    local cw=pw-24
    -- Keep switch controls left and executables right, including portrait phones.
    -- Narrow screens can pan Main horizontally instead of shrinking touch targets.
    local mainWidth=math.max(cw-5,260)
    local columnWidth=math.floor((mainWidth-24)/2)
    for _,control in ipairs(UI.featureToggles) do control:resize(columnWidth) end
    local rowHeight=UI.noFallToggle.button.Size.Y.Offset
    for index,control in ipairs(UI.featureToggles) do
        control.button.Position=UDim2.fromOffset(5,6+(index-1)*(rowHeight+12))
    end
    local manualY=6+#UI.featureToggles*(rowHeight+12)
    UI.disasterManual.Position=UDim2.fromOffset(5,manualY)
    UI.disasterManual.Size=UDim2.fromOffset(UI.noFallToggle.button.Size.X.Offset,52)
    UI.disasterManualCaption.TextSize=columnWidth<248 and 18 or 20
    UI.mainColumns.Size=UDim2.fromOffset(mainWidth,math.max(manualY+58,h-headerH-64))
    UI.mainLeft.Size=UDim2.new(0,columnWidth,1,0)
    UI.mainRight.Position=UDim2.fromOffset(columnWidth+24,0)
    UI.mainRight.Size=UDim2.new(0,columnWidth,1,0)
    UI.mainDivider.Position=UDim2.fromOffset(columnWidth+12,6)
    UI.mainDivider.Size=UDim2.new(0,1,1,-12)
    UI.flyButton.Size=UDim2.fromOffset(UI.noFallToggle.button.Size.X.Offset,rowHeight)
    UI.flyCaption.TextSize=columnWidth<248 and 18 or 20
    for index,action in ipairs(UI.mainActions)do
        action.button.Position=UDim2.fromOffset(5,6+index*(rowHeight+12))
        action.button.Size=UI.flyButton.Size;action.caption.TextSize=UI.flyCaption.TextSize
    end
    pages.Main.ScrollingDirection=Enum.ScrollingDirection.XY
    pages.Main.CanvasSize=UDim2.fromOffset(cw-5<mainWidth and mainWidth+5 or 0,UI.mainColumns.Size.Y.Offset)
    local scriptWidth=math.max(140,math.min(340,cw-16))
    local scriptHeight=#UI.scriptExecutables*74+6
    UI.scriptList.Size=UDim2.fromOffset(scriptWidth+10,scriptHeight)
    for _,control in ipairs(UI.scriptExecutables) do
        control.button.Size=UDim2.fromOffset(scriptWidth,60)
        control.caption.TextSize=scriptWidth<248 and 18 or 20
    end
    pages.Scripts.ScrollingDirection=Enum.ScrollingDirection.XY
    pages.Scripts.CanvasSize=UDim2.fromOffset(cw<scriptWidth+10 and scriptWidth+10 or 0,scriptHeight)
    UI.fpsToggle:resize(scriptWidth+16)
    local settingsY=UI.fpsToggle.button.Size.Y.Offset+18
    for index,action in ipairs(UI.serverActions)do
        action.button.Position=UDim2.fromOffset(5,settingsY+(index-1)*72)
        action.button.Size=UDim2.fromOffset(scriptWidth,60);action.caption.TextSize=scriptWidth<248 and 17 or 20
    end
    local settingsHeight=settingsY+#UI.serverActions*72
    UI.settingsList.Size=UDim2.fromOffset(scriptWidth+10,settingsHeight)
    pages.Settings.ScrollingDirection=Enum.ScrollingDirection.XY
    pages.Settings.CanvasSize=UDim2.fromOffset(cw<scriptWidth+10 and scriptWidth+10 or 0,settingsHeight)
    local narrow=cw<360
    local heroHeight=narrow and 246 or math.min(262,math.max(156,h-8-headerH-54))
    UI.hero.Size=UDim2.new(1,-8,0,heroHeight)
    UI.heroTitle.TextSize=narrow and math.min(36,math.floor((cw-28)/3)) or math.min(50,math.floor(cw*.46/3))
    UI.heroTitle.Position=UDim2.fromOffset(narrow and 14 or 22,narrow and 4 or 12)
    UI.heroTitle.Size=UDim2.fromOffset(narrow and cw-36 or math.min(268,cw*.48),narrow and 50 or math.min(96,heroHeight-92))
    UI.emblemHost.Size=UDim2.fromOffset(narrow and math.min(cw-38,152) or math.min(cw*.43,232),narrow and 104 or heroHeight-24)
    UI.emblemHost.Position=narrow and UDim2.new(.5,-UI.emblemHost.Size.X.Offset/2,0,54) or UDim2.new(1,-UI.emblemHost.Size.X.Offset-14,0,12)
    UI.status.Position=UDim2.fromOffset(narrow and 14 or 22,narrow and 172 or heroHeight-84)
    UI.status.Size=UDim2.fromOffset(narrow and cw-28 or math.min(206,cw*.46),58)
    local compact=narrow and cw<185
    UI.statusLabel.Size=UDim2.fromOffset(compact and 46 or 62,26)
    UI.versionLabel.Size=UDim2.fromOffset(compact and 46 or 62,26)
    UI.statusLabel.TextSize=compact and 15 or 17;UI.versionLabel.TextSize=compact and 15 or 17
    UI.statusDot.Visible=not compact
    UI.statusValue.Position=UDim2.fromOffset(compact and 52 or 82,0)
    UI.statusValue.Size=UDim2.new(1,compact and -52 or -82,0,26)
    UI.statusValue.TextSize=compact and 15 or 17
    UI.versionValue.Position=UDim2.fromOffset(compact and 52 or 71,29)
    UI.versionValue.Size=UDim2.new(1,compact and -52 or -71,0,26)
    pages.Home.CanvasSize=UDim2.fromOffset(0,heroHeight+10)
    UI.gui:SetAttribute("NavigationStep",step)
    applyPane();applyPage()
    -- Resize adapts dimensions only. It never forces a dragged position on-screen.
    if initial then recenter() end
end
local function setPane(open)
    if state.target=="closed" then return end
    state.paneOpen=open;UI.gui:SetAttribute("PanelOpen",open)
    tween(UI.paneProgress,.32,{Value=open and 1 or 0})
    UI.selectionLight.Visible=open
end
local function selectPage(name,toggle)
    if state.target=="closed" then return end
    if toggle and name==state.page and state.paneOpen then setPane(false);return end
    local changed=state.page~=name
    state.page=name;UI.gui:SetAttribute("Page",name)
    for other,page in pairs(pages) do page.Visible=other==name end
    local page=pages[name];page.CanvasPosition=Vector2.zero
    pcall(function() page:ResetScrollVelocity() end)
    UI.pageTitle.Text=name
    UI.pageTitle.FontFace=optionFont
    for other,n in pairs(navigation) do
        local selected=other==name
        n.fx.selected=selected
        tween(n.fx.selection,.24,{Value=selected and 1 or 0})
        tween(n.caption,.22,{TextColor3=selected and C.white or C.muted})
        tintIcon(n.icon,selected and C.light or C.silver)
    end
    tween(UI.selectionLight,.22,{Position=UDim2.fromOffset(0,(navigation[name].index-1)*layout.navStep+(layout.navStep-23)/2)})
    if changed then UI.pageFade.Value=0;tween(UI.pageFade,.24,{Value=1}) end
    setPane(true)
end
for name,n in pairs(navigation) do connect(n.button.Activated,function() selectPage(name,true) end) end
connect(UI.Collapse.Activated,function() setPane(not state.paneOpen) end)

-- Only the requested view extends to the right; folding leaves the dock alone.
connect(UI.paneProgress.Changed,applyPane)
connect(UI.pageFade.Changed,applyPage)
connect(UI.windowFade.Changed,refreshAlpha)
connect(UI.launcherFade.Changed,function()
    UI.launcherScale.Scale=.94+.06*UI.launcherFade.Value;refreshAlpha()
end)
connect(UI.zoom.Changed,function() UI.scale.Scale=UI.zoom.Value end)
connect(UI.screen:GetPropertyChangedSignal("AbsoluteSize"),function() resize(false) end)
local function offscreen(object)
    local p,s=object.AbsolutePosition,object.AbsoluteSize;local v=UI.screen.AbsoluteSize
    return p.X+s.X<8 or p.Y+s.Y<8 or p.X>v.X-8 or p.Y>v.Y-8
end
local function transition(target)
    if not state.alive or state.target=="closed" then return end
    state.drag=nil
    tween(UI.launcherPress,.16,{Scale=1})
    state.target=target;state.burst=1;state.finishAt=os.clock()+.34
    UI.gui:SetAttribute("Minimized",target=="minimized")
    UI.gui:SetAttribute("Transition",target=="closed" and "closing" or target=="minimized" and "minimizing" or "opening")
    UI.recovery.Visible=false
    if target=="closed" then
        UI.loadToast:dismiss(.22);UI.disasterToast:dismiss(.22);features.disasterPrediction:destroy()
        features.serverTravel:destroy();features.fpsCounter:destroy()
    end
    if target=="open" then
        UI.window.Visible=true
        tween(UI.windowFade,.28,{Value=1});tween(UI.zoom,.32,{Value=1})
        tween(UI.launcherFade,.2,{Value=0})
    else
        if target=="minimized" then UI.launcher.Visible=true end
        tween(UI.windowFade,.25,{Value=0});tween(UI.zoom,.3,{Value=.985})
        tween(UI.launcherFade,target=="minimized" and .3 or .22,{Value=target=="minimized" and 1 or 0})
    end
end
connect(UI.Minimize.Activated,function() transition("minimized") end)
connect(UI.Close.Activated,function() transition("closed") end)
connect(UI.launcher.Activated,function()
    if state.suppressLauncherUntil and os.clock()<state.suppressLauncherUntil then return end
    if offscreen(UI.window) then recenter() end
    transition("open")
end)
connect(UI.recovery.Activated,function() recenter();transition("open") end)

-- Drag uses screen-pixel deltas, with no viewport clamp or fullscreen constraint.
-- Only the initiating pointer can move/end a drag; scrolling content never does.
local function beginDrag(target,input)
    if state.target=="closed" or state.drag then return end
    local kind=input.UserInputType
    if kind~=Enum.UserInputType.MouseButton1 and kind~=Enum.UserInputType.Touch then return end
    if target==UI.launcher then state.suppressLauncherUntil=nil end
    state.drag={target=target,input=input,touch=kind==Enum.UserInputType.Touch,start=input.Position,position=target.Position,moved=false}
end
connect(UI.dragArea.InputBegan,function(input) beginDrag(UI.window,input) end)
connect(UI.panelDrag.InputBegan,function(input) beginDrag(UI.window,input) end)
connect(UI.fpsHost.InputBegan,function(input)
    if features.fpsCounter.enabled then beginDrag(UI.fpsHost,input) end
end)
connect(UI.launcher.InputBegan,function(input)
    beginDrag(UI.launcher,input)
    if state.drag and state.drag.target==UI.launcher and state.drag.input==input then
        tween(UI.launcherPress,.12,{Scale=.965})
    end
end)
connect(Input.InputChanged,function(input)
    local drag=state.drag
    if not drag then return end
    if drag.touch and input~=drag.input then return end
    if not drag.touch and input.UserInputType~=Enum.UserInputType.MouseMovement then return end
    local delta=input.Position-drag.start
    if not drag.moved and delta.Magnitude<5 then return end
    drag.moved=true
    drag.target.Position=UDim2.new(drag.position.X.Scale,drag.position.X.Offset+delta.X,drag.position.Y.Scale,drag.position.Y.Offset+delta.Y)
    if drag.target==UI.launcher then state.launcherMoved=true end
end)
local function endDrag(input,force)
    local drag=state.drag
    if not drag then return end
    if not force and ((drag.touch and input~=drag.input) or (not drag.touch and input.UserInputType~=Enum.UserInputType.MouseButton1)) then return end
    if drag.target==UI.launcher then
        tween(UI.launcherPress,.2,{Scale=1})
        if drag.moved then state.suppressLauncherUntil=os.clock()+.4 end
    end
    state.drag=nil
end
connect(Input.InputEnded,function(input) endDrag(input,false) end)
connect(Input.WindowFocusReleased,function() endDrag(nil,true) end)
connect(Input.InputBegan,function(input,processed)
    if processed or Input:GetFocusedTextBox() then return end
    if input.KeyCode==Enum.KeyCode.RightShift then
        if offscreen(state.target=="minimized" and UI.launcher or UI.window) then recenter();transition("open")
        else transition(state.target=="open" and "minimized" or "open") end
    end
end)

-- Original logos/controls, supplied option icons/background and shared fire sprite.
-- The previous wordmark PNG remains in the repository but is no longer loaded.
-- Custom artwork needs the executor's local asset API; failure never blocks the GUI.
local ASSETS={
    FPSPanel={url="https://raw.githubusercontent.com/hzReyzn/Ghislain/main/assets/reyzn-x/fps-panel-v1.png",file="ReyznX-fps-panel-v1.png",bytes=1502075,refresh=true,images={UI.fpsImage}},
    DisasterSuccess={url="https://raw.githubusercontent.com/hzReyzn/Ghislain/main/assets/reyzn-x/disaster-success-v1.png",file="ReyznX-disaster-success-v1.png",bytes=1346483,refresh=true,images={UI.disasterToast.icons.detected.image,UI.disasterToast.icons.detected.glow}},
    DisasterFailure={url="https://raw.githubusercontent.com/hzReyzn/Ghislain/main/assets/reyzn-x/disaster-failure-v1.png",file="ReyznX-disaster-failure-v1.png",bytes=1491592,refresh=true,images={UI.disasterToast.icons.unavailable.image,UI.disasterToast.icons.unavailable.glow}},
    IconHome={url="https://raw.githubusercontent.com/hzReyzn/Ghislain/main/assets/reyzn-x/icon-home-v1.png",file="ReyznX-icon-home-v1.png",bytes=1933132,images=artworkImages.IconHome},
    IconMain={url="https://raw.githubusercontent.com/hzReyzn/Ghislain/main/assets/reyzn-x/icon-main-v1.png",file="ReyznX-icon-main-v1.png",bytes=2142879,images=artworkImages.IconMain},
    IconVisuals={url="https://raw.githubusercontent.com/hzReyzn/Ghislain/main/assets/reyzn-x/icon-visuals-v1.png",file="ReyznX-icon-visuals-v1.png",bytes=1628114,images=artworkImages.IconVisuals},
    IconScripts={url="https://raw.githubusercontent.com/hzReyzn/Ghislain/main/assets/reyzn-x/icon-scripts-v1.png",file="ReyznX-icon-scripts-v1.png",bytes=2546120,images=artworkImages.IconScripts},
    IconSettings={url="https://raw.githubusercontent.com/hzReyzn/Ghislain/main/assets/reyzn-x/icon-settings-v1.png",file="ReyznX-icon-settings-v1.png",bytes=1892474,images=artworkImages.IconSettings},
    Background={url="https://raw.githubusercontent.com/hzReyzn/Ghislain/main/assets/reyzn-x/background-cyber-v2.jpg",file="ReyznX-background-cyber-v2.jpg",bytes=167325,format="jpeg",images=artworkImages.Background},
    R={url="https://raw.githubusercontent.com/hzReyzn/Ghislain/main/assets/reyzn-x/launcher-r-v1.png",file="ReyznX-launcher-r-v1.png",bytes=2136070,images={UI.launcherImage,UI.recoveryImage,UI.launcherShine}},
    X={url="https://raw.githubusercontent.com/hzReyzn/Ghislain/main/assets/reyzn-x/emblem-x-v1.png",file="ReyznX-emblem-x-v1.png",bytes=1699126,images=artworkImages.Emblem},
    Fire={url="https://raw.githubusercontent.com/hzReyzn/Ghislain/main/assets/reyzn-x/flame-wisp-v1.png",file="ReyznX-flame-wisp-v1.png",bytes=1172326,images=VFX.images},
    Minimize={url="https://raw.githubusercontent.com/hzReyzn/Ghislain/main/assets/reyzn-x/minimize-v1.png",file="ReyznX-minimize-v1.png",bytes=1283532,images={controlArtwork.Minimize.image,controlArtwork.Minimize.glow},rect={Vector2.new(260,101),Vector2.new(1253,680)}},
    Collapse={url="https://raw.githubusercontent.com/hzReyzn/Ghislain/main/assets/reyzn-x/collapse-v1.png",file="ReyznX-collapse-v1.png",bytes=1337784,images={controlArtwork.Collapse.image,controlArtwork.Collapse.glow},rect={Vector2.new(254,103),Vector2.new(1268,683)}},
    Close={url="https://raw.githubusercontent.com/hzReyzn/Ghislain/main/assets/reyzn-x/close-v1.png",file="ReyznX-close-v1.png",bytes=1570916,images={controlArtwork.Close.image,controlArtwork.Close.glow},rect={Vector2.new(187,84),Vector2.new(1401,713)}},
}
local function validArtwork(body,asset)
    if type(body)~="string" or #body~=asset.bytes then return false end
    -- The supplied background was named .png but contains original JPEG bytes.
    -- Validate its real format; never silently reject it as a malformed PNG.
    if asset.format=="jpeg" then return body:sub(1,3)=="\255\216\255" and body:sub(-2)=="\255\217" end
    return body:sub(1,8)=="\137PNG\13\10\26\10" and body:sub(13,16)=="IHDR" and body:sub(-8,-5)=="IEND"
end
local function loadAsset(key,asset)
    local customAsset=getcustomasset or getsynasset
    if type(customAsset)~="function" or type(writefile)~="function" then
        UI.gui:SetAttribute("Asset"..key,"unavailable")
        warn("Reyzn X: custom artwork requires getcustomasset/getsynasset and writefile.")
        return
    end
    local cached=false
    if type(isfile)=="function" and type(readfile)=="function" then
        local ok,body=pcall(function() if isfile(asset.file) then return readfile(asset.file) end end)
        cached=ok and validArtwork(body,asset)
    end
    local uri
    if cached then local ok,value=pcall(customAsset,asset.file);if ok and type(value)=="string" and value~="" then uri=value end end
    if not uri then
        for attempt=1,2 do
            if not state.alive then return end
            local url=asset.url
            -- New notice images must not reuse a cached 404 from before they
            -- were published. Valid local PNGs are still reused without HTTP.
            if asset.refresh then url..="?build="..BUILD.."&t="..tostring(os.time()).."&attempt="..attempt end
            local ok,body=pcall(function() return game:HttpGet(url) end)
            if not state.alive then return end
            if ok and validArtwork(body,asset) then
                local wrote=pcall(writefile,asset.file,body)
                if wrote then
                    local registered,value=pcall(customAsset,asset.file)
                    if registered and type(value)=="string" and value~="" then uri=value;break end
                end
            end
            if attempt==1 then task.wait(.6) end
        end
    end
    if not state.alive then return end
    if not uri then UI.gui:SetAttribute("Asset"..key,"failed");warn("Reyzn X: could not load the "..key.." artwork.");return end
    for _,o in ipairs(asset.images) do
        -- Use only the visible artwork region; original image bytes are unchanged.
        if asset.rect then o.ImageRectOffset=asset.rect[1];o.ImageRectSize=asset.rect[2] end
        o.Image=uri
    end
    UI.gui:SetAttribute("Asset"..key,"assigned")
    -- Preloading runs separately from input, animation and the session clock.
    pcall(function() ContentProvider:PreloadAsync(asset.images) end)
end
for key,asset in pairs(ASSETS) do spawn(function() loadAsset(key,asset) end) end
spawn(function()
    local ok,uri=pcall(function() return Players:GetUserThumbnailAsync(player.UserId,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size150x150) end)
    if state.alive and ok and type(uri)=="string" and uri~="" then UI.avatar.Image=uri end
end)
local function updateClock()
    local seconds=math.max(0,math.floor(os.clock()-startedAt))
    if seconds~=state.lastSecond then
        state.lastSecond=seconds;UI.gui:SetAttribute("ElapsedSeconds",seconds)
        UI.session.Text=string.format("%02d:%02d:%02d",math.floor(seconds/3600),math.floor(seconds/60)%60,seconds%60)
    end
end
resize(true)
selectPage("Home",false)
UI.gui:SetAttribute("PanelOpen",true)
UI.gui:SetAttribute("Minimized",false)
updateClock();refreshAlpha();transition("open");UI.loadToast:start()
connect(RunService.Heartbeat,function(dt)
    updateClock()
    updateDisasterManual()
    if state.finishAt>0 and os.clock()>=state.finishAt then
        state.finishAt=0
        if state.target=="closed" then UI.gui:Destroy();return end
        UI.window.Visible=state.target=="open"
        UI.launcher.Visible=state.target=="minimized"
        UI.gui:SetAttribute("Transition",state.target)
    end
    state.budget+=dt
    state.effectElapsed=(state.effectElapsed or 0)+dt
    local interval=1/VFX_RATE
    if state.budget<interval then return end
    local elapsed=state.effectElapsed;state.effectElapsed=0
    state.budget=state.budget%interval;state.phase+=elapsed
    state.burst=math.max(0,state.burst-elapsed*3)
    local p=state.phase
    -- Notifications keep their own lifetime, including while the window or
    -- launcher is minimized, folded or dragged entirely off the screen.
    UI.loadToast:update(os.clock(),p)
    UI.disasterToast:update(os.clock(),p)
    local pulse=.5+.5*math.sin(p*1.8)
    UI.recovery.Visible=state.target~="closed" and state.finishAt==0 and offscreen(state.target=="minimized" and UI.launcher or UI.window)
    if p>=(state.assetPoll or 0) then
        state.assetPoll=p+.2
        UI.disasterToast:refreshIcons()
        UI.fpsFallback.Visible=UI.fpsImage.Image=="" or not UI.fpsImage.IsLoaded
        if not UI.fpsFallback.Visible then UI.gui:SetAttribute("AssetFPSPanel","ready") end
        UI.avatarFallback.Visible=UI.avatar.Image=="" or not UI.avatar.IsLoaded
        UI.rFallback.Visible=UI.launcherImage.Image=="" or not UI.launcherImage.IsLoaded
        UI.recoveryFallback.Visible=UI.recoveryImage.Image=="" or not UI.recoveryImage.IsLoaded
        UI.xFallback.Visible=UI.xImage.Image=="" or not UI.xImage.IsLoaded
        for name,control in pairs(controlArtwork) do
            control.fallback.Visible=control.image.Image=="" or not control.image.IsLoaded
            if not control.fallback.Visible then UI.gui:SetAttribute("Asset"..name,"ready") end
        end
        if not UI.xFallback.Visible then UI.gui:SetAttribute("AssetX","ready") end
        if not UI.rFallback.Visible then UI.gui:SetAttribute("AssetR","ready") end
        if VFX.images[1].Image~="" and VFX.images[1].IsLoaded then UI.gui:SetAttribute("AssetFire","ready") end
        for _,sprite in ipairs(iconSprites) do
            local ready=sprite.image.Image~="" and sprite.image.IsLoaded
            for _,line in ipairs(sprite.fallback) do line.Visible=not ready end
            if ready then UI.gui:SetAttribute("Asset"..sprite.key,"ready") end
        end
        if artworkImages.Background[1].Image~="" and artworkImages.Background[1].IsLoaded then
            UI.gui:SetAttribute("AssetBackground","ready")
        end
    end
    local visibleTarget=state.target=="minimized" and UI.launcher or UI.window
    if state.finishAt==0 and offscreen(visibleTarget) then return end
    if UI.launcher.Visible then
        UI.launcherAura:update(p,state.burst)
        local cycle=p%5.1
        local sweep=math.min(1,cycle/1.25)
        UI.launcherSweep.Offset=Vector2.new(-1+2*sweep,0)
        alpha(UI.launcherShine,"ImageTransparency",1-math.sin(sweep*math.pi)^2*.24)
    end
    VFX.reflections:update(elapsed)
    if state.target=="minimized" and state.finishAt==0 then return end
    UI.dockAura:update(p,state.burst)
    if UI.panelAura.host.Visible then UI.panelAura:update(p+.63,state.burst) end
    for i,fx in ipairs(VFX.surfaces) do
        if i==1 or UI.panelAura.host.Visible then
            fx.inward:update(p,state.burst)
            fx.neon:update(p,.105+.015*math.sin(p*.7+i)^2)
            local breath=.5+.5*math.sin(p*.65+i*1.7)
            alpha(fx.beam,"BackgroundTransparency",.72-.12*breath-.12*state.burst)
            fx.beamGradient.Offset=Vector2.new(math.sin(p*.18+i)*.34,0)
        end
    end
    for _,record in ipairs(buttons) do
        record.neon:update(p,.085+record.selection.Value*.11+record.energy.Value*.04)
        record.selectedGradient.Offset=record.neon.wash.Offset
    end
    if state.page=="Home" and state.paneOpen then
        UI.heroNeon:update(p,.085)
        UI.emblemNeon:update(p,state.burst)
        alpha(UI.statusDot,"BackgroundTransparency",.08+.12*pulse)
    end
    if state.page=="Main" and state.paneOpen then
        for _,control in ipairs(UI.featureToggles) do control:update(p) end
    end
    if state.page=="Settings" and state.paneOpen then UI.fpsToggle:update(p) end
end)
return UI.gui
