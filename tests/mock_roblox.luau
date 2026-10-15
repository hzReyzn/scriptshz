-- Small deterministic client harness. It checks controller behavior, not Roblox physics/rendering.
local function newWorld()
    local W={time=0,tasks={},warnings={},objects={},requests={},viewport={X=1280,Y=720},rejectVideoCanvas=true}
    local env=setmetatable({}, {__index=getfenv()})
    local function signal()
        local s={links={}}
        function s:Connect(fn)
            local c={Connected=true,fn=fn}
            function c:Disconnect() self.Connected=false end
            self.links[#self.links+1]=c;return c
        end
        function s:Fire(...)
            for _,c in ipairs(table.clone(self.links)) do if c.Connected then W.spawn(c.fn,...) end end
        end
        function s:Wait() return coroutine.yield({signal=self}) end
        function s:Count() local n=0;for _,c in ipairs(self.links) do if c.Connected then n+=1 end end;return n end
        return s
    end
    local function schedule(co,args,at) W.tasks[#W.tasks+1]={co=co,args=args or {},at=at or W.time} end
    function W.resume(co,...)
        if coroutine.status(co)=="dead" then return end
        local ok,value=coroutine.resume(co,...)
        assert(ok,value)
        if coroutine.status(co)~="dead" then
            if type(value)=="table" and value.signal then
                local c;c=value.signal:Connect(function(...) c:Disconnect();W.resume(co,...) end)
            else
                local wait=type(value)=="number" and math.max(value,1/60) or 1/60
                schedule(co,{wait},W.time+wait)
            end
        end
    end
    function W.spawn(fn,...) local co=coroutine.create(fn);W.resume(co,...);return co end
    env.task={spawn=W.spawn,defer=function(fn,...)local co=coroutine.create(fn);schedule(co,{...});return co end,
        delay=function(t,fn,...)local co=coroutine.create(fn);schedule(co,{...},W.time+t);return co end,
        wait=function(t)return coroutine.yield(t or 1/60)end,
        cancel=function(co) if coroutine.status(co)~="dead" then coroutine.close(co) end end}
    env.os=table.clone(os);env.os.clock=function()return W.time end
    env.warn=function(...)W.warnings[#W.warnings+1]=table.concat({...}," ")end
    env.print=function()end
    local vec={};vec.__index=vec
    function vec.new(x,y,z)return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},vec)end
    function vec.__add(a,b)return vec.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end
    function vec.__sub(a,b)return vec.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
    function vec.__mul(a,b)if type(a)=="number" then a,b=b,a end;return vec.new(a.X*b,a.Y*b,a.Z*b)end
    function vec.__div(a,b)return a*(1/b)end
    function vec.__unm(a)return a*-1 end
    function vec:Dot(b)return self.X*b.X+self.Y*b.Y+self.Z*b.Z end
    function vec:Lerp(b,t)return self+(b-self)*t end
    vec.__index=function(t,k)
        if k=="Magnitude" then return math.sqrt(t:Dot(t)) end
        if k=="Unit" then return t/t.Magnitude end
        return vec[k]
    end
    env.Vector3={new=vec.new,zero=vec.new(),xAxis=vec.new(1,0,0),yAxis=vec.new(0,1,0),zAxis=vec.new(0,0,1)}
    env.Vector2={new=vec.new,zero=vec.new()}
    local cf={};cf.__index=cf
    function cf.new(x,y,z)
        local pos=type(x)=="table" and x or vec.new(x,y,z)
        return setmetatable({Position=pos,X=pos.X,Y=pos.Y,Z=pos.Z,RightVector=vec.new(1,0,0),UpVector=vec.new(0,1,0),LookVector=vec.new(0,0,-1)},cf)
    end
    cf.__index=function(t,k)if k=="Rotation" then return cf.new() end;return cf[k]end
    function cf.__mul(a,b)return cf.new(a.Position+b.Position)end
    function cf.__add(a,b)return cf.new(a.Position+b)end
    function cf:PointToObjectSpace(v)return v-self.Position end
    function cf:PointToWorldSpace(v)return v+self.Position end
    function cf:VectorToObjectSpace(v)return v end
    env.CFrame={new=cf.new,Angles=function()return cf.new()end,lookAt=function(p)return cf.new(p)end}
    local color={};color.__index=color
    function color.new(r,g,b)return setmetatable({R=r,G=g,B=b},color)end
    function color:Lerp(b,t)return color.new(self.R+(b.R-self.R)*t,self.G+(b.G-self.G)*t,self.B+(b.B-self.B)*t)end
    env.Color3={new=color.new,fromRGB=function(r,g,b)return color.new(r/255,g/255,b/255)end,
        fromHSV=function(h,s,v)return color.new(v*(1-s*h),v*(1-s*(1-h)),v)end}
    env.UDim={new=function(s,o)return {Scale=s,Offset=o}end}
    env.UDim2={new=function(x,xo,y,yo)return {X={Scale=x,Offset=xo},Y={Scale=y,Offset=yo}}end}
    env.UDim2.fromScale=function(x,y)return env.UDim2.new(x,0,y,0)end
    env.UDim2.fromOffset=function(x,y)return env.UDim2.new(0,x,0,y)end
    for _,key in ipairs({"ColorSequence","ColorSequenceKeypoint","NumberSequence","NumberSequenceKeypoint","NumberRange","TweenInfo","Font"}) do
        env[key]={new=function(...)return {...}end}
    end
    env.Enum=setmetatable({}, {__index=function(t,k)
        local group=setmetatable({}, {__index=function(a,b)local e={Name=b,Value=1};rawset(a,b,e);return e end})
        rawset(t,k,group);return group
    end})
    env.Random={new=function()return {NextNumber=function(_,a,b)return (a+b)/2 end,NextInteger=function(_,a,b)return math.floor((a+b)/2)end}end}
    env.OverlapParams={new=function()return {}end};env.RaycastParams={new=function()return {}end}
    local methods={}
    local events={Ended=true,Loaded=true,TeleportInitFailed=true,Destroying=true,ChildAdded=true,ChildRemoved=true,Changed=true,Activated=true,InputBegan=true,InputEnded=true,InputChanged=true,MouseEnter=true,MouseLeave=true,FocusLost=true,Died=true,StateChanged=true,CharacterAdded=true,CharacterRemoving=true,WindowFocusReleased=true,JumpRequest=true}
    local guiClasses={Frame=true,CanvasGroup=true,TextLabel=true,TextButton=true,TextBox=true,ImageLabel=true,ImageButton=true,ScrollingFrame=true,VideoFrame=true}
    local mt={}
    mt.__index=function(t,k)
        if methods[k] then return methods[k] end
        if events[k] then if not t._signals[k] then t._signals[k]=signal()end;return t._signals[k]end
        if k=="AbsoluteSize" then return t._props.AbsoluteSize or vec.new(760,450)end
        if k=="AbsolutePosition" then return vec.new(20,20)end
        if k=="AbsoluteContentSize" then return vec.new(510,600)end
        if k=="AssemblyRootPart" then return t end
        if k=="Position" and t:IsA("BasePart") then return t._props.CFrame.Position end
        return t._props[k]
    end
    mt.__newindex=function(t,k,v)
        local old=t._props[k]
        if k=="Parent" and old~=v then
            if old then
                local index=table.find(old._children,t);if index then table.remove(old._children,index)end
            end
            t._props[k]=v
            if v then v._children[#v._children+1]=t end
            if old then old.ChildRemoved:Fire(t)end
            if v then v.ChildAdded:Fire(t)end
        else t._props[k]=v end
        if k=='Video' and t.ClassName=='VideoFrame' then
            t._props.IsLoaded=not (W.rejectWebm and v:find('webm'))
            if W.localStatusFalse then t._props.IsLoaded=false end
        elseif k=='Image' and (t.ClassName=='ImageLabel' or t.ClassName=='ImageButton') then
            t._props.IsLoaded=false
        end
        if old~=v then
            if t._signals[k] then t._signals[k]:Fire(v)end
            if t._signals.Changed then t._signals.Changed:Fire(v)end
        end
    end
    function methods:IsA(c)return c==self.ClassName or c=="Instance" or (c=="GuiObject" and guiClasses[self.ClassName]) or (c=="BasePart" and (self.ClassName=="Part" or self.ClassName=="Seat"))end
    function methods:GetChildren()return table.clone(self._children)end
    function methods:GetDescendants()
        local found={}
        for _,c in ipairs(self._children) do found[#found+1]=c;for _,d in ipairs(c:GetDescendants())do found[#found+1]=d end end
        return found
    end
    function methods:FindFirstChild(n,recurse)
        for _,c in ipairs(recurse and self:GetDescendants() or self._children)do if c.Name==n then return c end end
    end
    function methods:FindFirstChildOfClass(c)for _,o in ipairs(self._children)do if o.ClassName==c then return o end end end
    function methods:FindFirstChildWhichIsA(c,recurse)for _,o in ipairs(recurse and self:GetDescendants() or self._children)do if o:IsA(c)then return o end end end
    function methods:WaitForChild(n)return self:FindFirstChild(n)end
    function methods:FindFirstAncestorOfClass(c)local p=self.Parent;while p do if p:IsA(c)then return p end;p=p.Parent end end
    function methods:IsDescendantOf(a)local p=self.Parent;while p do if p==a then return true end;p=p.Parent end;return false end
    function methods:GetFullName()return self.Name end
    function methods:GetPropertyChangedSignal(k)if not self._signals[k]then self._signals[k]=signal()end;return self._signals[k]end
    function methods:SetAttribute(k,v)local old=self._attributes[k];self._attributes[k]=v;if old~=v and self._signals['@'..k]then self._signals['@'..k]:Fire()end end
    function methods:GetAttribute(k)return self._attributes[k]end
    function methods:GetAttributeChangedSignal(k)return self:GetPropertyChangedSignal('@'..k)end
    function methods:ClearAllChildren()for _,c in ipairs(self:GetChildren())do c:Destroy()end end
    function methods:Destroy()
        if self._destroying then return end
        rawset(self,'_destroying',true);self.Destroying:Fire();self:ClearAllChildren();self.Parent=nil
        for _,s in pairs(self._signals)do for _,c in ipairs(s.links)do c:Disconnect()end end
    end
    function methods:ChangeState(s)local old=self.State;self.State=s;self.StateChanged:Fire(old,s)end
    function methods:GetState()return self.State end
    function methods:GetConnectedParts()return {}end
    function methods:Play()self.IsPlaying=true;self.Playing=true end
    function methods:Pause()self.IsPlaying=false;self.Playing=false end
    function methods:Resume()self.IsPlaying=true;self.Playing=true end
    function methods:Stop()self.IsPlaying=false;self.Playing=false;self.TimePosition=0 end
    function methods:Emit()end
    function methods:Clear()end
    function methods:LoadAnimation()local track=env.Instance.new('AnimationTrack');track.Length=1;return track end
    function methods:Fire(...)if self.Event then self.Event:Fire(...)end end
    env.Instance={new=function(c)
        local t=setmetatable({_props={ClassName=c,Name=c,Visible=true,Enabled=true,BackgroundTransparency=0,TextTransparency=0,ImageTransparency=0,Transparency=0,ScrollBarImageTransparency=0,
            Text="",Image="",BackgroundColor3=color.new(1,1,1),Size=env.UDim2.fromOffset(100,100),Position=env.UDim2.fromOffset(0,0),Value=0,CFrame=cf.new(),AssemblyLinearVelocity=vec.new(),AssemblyAngularVelocity=vec.new(),AssemblyMass=10,
            Health=100,AutoRotate=true,PlatformStand=false,Anchored=false,CanCollide=true,WalkSpeed=16,HipHeight=2,MoveDirection=vec.new(),FloorMaterial=env.Enum.Material.Air,State=env.Enum.HumanoidStateType.Freefall,
            RigType=env.Enum.HumanoidRigType.R6,UseJumpPower=true,JumpPower=50,IsLoaded=true,Volume=0,TimeLength=18.35,TimePosition=0,Video='',Playing=false},_children={},_signals={},_attributes={}},mt)
        if c=='BindableEvent'then t.Event=signal()end
        W.objects[#W.objects+1]=t;return t
    end}
    env.typeof=function(v)if type(v)=='table' and v._props then return 'Instance'end;if getmetatable(v)==vec then return 'Vector3'end;return type(v)end
    local services={}
    services.RunService={PreSimulation=signal(),PostSimulation=signal(),Heartbeat=signal(),RenderStepped=signal()}
    services.TweenService={Create=function(_,object,info,props)
        local t={Completed=signal(),cancelled=false}
        function t:Cancel()self.cancelled=true end
        function t:Play()env.task.delay(info[1] or .1,function()if not t.cancelled and not object._destroying then for k,v in pairs(props)do object[k]=v end;t.Completed:Fire()end end)end
        return t
    end,GetValue=function(_,x)return x end}
    services.UserInputService=env.Instance.new('UserInputService');services.UserInputService.TouchEnabled=true
    services.UserInputService.GetFocusedTextBox=function()return nil end
    services.UserInputService.GetMouseLocation=function()return vec.new(500,300)end
    services.ContentProvider={PreloadAsync=function()end};services.SoundService=env.Instance.new('SoundService')
    env.workspace=env.Instance.new('Workspace');env.workspace.Name='Workspace';env.workspace.Gravity=196.2
    env.workspace.CurrentCamera=env.Instance.new('Camera');env.workspace.CurrentCamera.ViewportSize=vec.new(1280,720)
    env.workspace.GetPartBoundsInRadius=function()return {}end;env.workspace.GetPartBoundsInBox=function()return {}end;env.workspace.Raycast=function()return nil end
    local player=env.Instance.new('Player');player.Name='TestPlayer';player.DisplayName='Test';player.UserId=123
    local pg=env.Instance.new('PlayerGui');pg.Parent=player
    local scripts=env.Instance.new('PlayerScripts');scripts.Parent=player
    services.Players={LocalPlayer=player,GetPlayers=function()return {player}end,GetUserThumbnailAsync=function()return ''end}
    env.game={PlaceId=189707,JobId='test',GetService=function(_,name)if not services[name]then services[name]=env.Instance.new(name)end;return services[name]end,
        HttpGet=function(_,url)
            W.requests[#W.requests+1]=url
            local body=W.http[url] or W.http[url:match('^[^?]+')]
            assert(body,url);return body
        end,GetObjects=function()return {}end}
    env.loadstring=function(src)local fn,err=loadstring(src);if fn then setfenv(fn,env)end;return fn,err end
    env.isfile=function()return true end;env.writefile=function()end;env.getcustomasset=function(path)return 'mock://'..path end
    W.env=env;W.services=services;W.player=player;W.pg=pg;W.http={}
    local function renderable(object,isVideo)
        local node=object
        while node do
            if node:IsA('GuiObject') and not node.Visible then return false end
            if node.ClassName=='ScreenGui' and not node.Enabled then return false end
            if node.ClassName=='CanvasGroup' then
                if isVideo and W.rejectVideoCanvas then return false end
                if node.GroupTransparency and node.GroupTransparency>=1 then return false end
            end
            node=node.Parent
        end
        return object:IsDescendantOf(pg)
    end
    function W.run(src,...)local fn,err=env.loadstring(src);assert(fn,err);local result;W.spawn(function(...)result=fn(...)end,...);return result end
    function W.step(count)
        for _=1,(count or 1)do
            W.time+=1/60
            for _,object in ipairs(W.objects) do
                if (object.ClassName=='ImageLabel' or object.ClassName=='ImageButton') and object.Image~='' and not object.IsLoaded
                    and not W.localStatusFalse and renderable(object,false) then object.IsLoaded=true end
                local rejected=W.rejectWebm and object.Video:find('webm')
                if object.ClassName=='VideoFrame' and object.Parent and object.Video~='' and (object.IsLoaded or W.localStatusFalse)
                    and not rejected and object.Playing and not W.stallVideo and renderable(object,true) then
                    object.TimePosition=math.min(object.TimeLength,object.TimePosition+1/60)
                    if object.TimePosition>=object.TimeLength then object.Playing=false;object.Ended:Fire(object.Video) end
                end
                if object.ClassName=='Sound' and object.Parent and object.Playing then
                    object.TimePosition=math.min(object.TimeLength,object.TimePosition+1/60)
                    if object.TimePosition>=object.TimeLength then object.Playing=false;object.IsPlaying=false;object.Ended:Fire() end
                end
            end
            for _,key in ipairs({'PreSimulation','PostSimulation','Heartbeat','RenderStepped'})do services.RunService[key]:Fire(1/60)end
            local pending=W.tasks;W.tasks={}
            for _,t in ipairs(pending)do if t.at<=W.time then W.resume(t.co,table.unpack(t.args))else W.tasks[#W.tasks+1]=t end end
        end
    end
    function W.character(health)
        local old=player.Character
        if old then player.CharacterRemoving:Fire(old);old.Parent=nil end
        local model=env.Instance.new('Model');model.Name='Character';model.Parent=env.workspace
        local hum=env.Instance.new('Humanoid');hum.Health=health or 100;hum.Parent=model
        local root=env.Instance.new('Part');root.Name='HumanoidRootPart';root.Size=vec.new(2,2,1);root.Parent=model
        local animator=env.Instance.new('Animator');animator.Parent=hum
        player.Character=model;player.CharacterAdded:Fire(model)
        return model,hum,root
    end
    return W
end
return newWorld
