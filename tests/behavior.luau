local function runTests(source)
    local world=require('./mock_roblox')
    local passed=0
    local function test(name,fn)fn();passed+=1;print('PASS '..name)end
    local function near(a,b)return math.abs(a-b)<.001 end
    local function find(parent,name)return assert(parent:FindFirstChild(name,true),name)end
    test('Maintenance shows only a dismissible notice with no downloads or modules',function()
        local w=world();w.character()
        assert(w.run(source.maintenance)=='maintenance');w.step(90)
        local notice=find(w.pg,'HzReyznMaintenance')
        assert(find(notice,'Message').Text=='El script está en mantenimiento.\nRegresará pronto.')
        assert(not w.pg:FindFirstChild('HzReyznInterface') and not w.pg:FindFirstChild('HzReyznHalloweenLoading'))
        assert(not w.pg:FindFirstChild('HzReyzn_NoFallDamage_v4') and not w.pg:FindFirstChild('HZFlightStandalone'))
        assert(#w.requests==0 and #w.warnings==0)
        find(notice,'Dismiss').Activated:Fire();w.step(1800)
        assert(not notice.Parent and not w.pg:FindFirstChild('HzReyznInterface') and #w.requests==0)
        assert(w.services.RunService.Heartbeat:Count()==0 and w.services.RunService.RenderStepped:Count()==0)
    end)
    test('Maintenance retires an existing Hub and intro, and stays single on re-execution',function()
        local w=world();w.character()
        w.http['https://raw.githubusercontent.com/hzReyzn/scriptshz/main/HzReyzn_Halloween.client.lua']=source.loader
        w.run(source.hub);w.step(90)
        local hub=find(w.pg,'HzReyznInterface');local movie=find(w.pg,'HzReyznHalloweenLoading')
        local requests=#w.requests
        w.run(source.maintenance);w.step(30)
        local notice=find(w.pg,'HzReyznMaintenance')
        assert(not hub.Parent and not movie.Parent and #w.requests==requests)
        w.run(source.maintenance);w.step(30)
        assert(not notice.Parent and find(w.pg,'HzReyznMaintenance'))
        local count=0
        for _,o in ipairs(w.pg:GetChildren()) do if o.Name=='HzReyznMaintenance' then count+=1 end end
        assert(count==1 and #w.requests==requests)
        assert(w.services.RunService.Heartbeat:Count()==0 and w.services.RunService.RenderStepped:Count()==0)
    end)
    test('NoFall leases, respawn, direction and competing flight',function()
        local w=world();local char,h,r=w.character()
        local factory=w.run('local player=game:GetService("Players").LocalPlayer\nlocal playerGui=player:WaitForChild("PlayerGui")\nlocal RunService=game:GetService("RunService")\n'..source.nofall..'\nreturn acquireNoFall')
        local a=w.env.Instance.new('ScreenGui');a.Parent=w.pg
        local b=w.env.Instance.new('ScreenGui');b.Parent=w.pg
        local releaseA,releaseB=factory(a),factory(b)
        local service=find(w.pg,'HzReyzn_NoFallDamage_v4')
        assert(#service:GetChildren()==2)
        assert(w.services.RunService.PreSimulation:Count()==1)
        r.AssemblyLinearVelocity=w.env.Vector3.new(12,-120,9);w.step()
        assert(r.AssemblyLinearVelocity.Y==0 and r.AssemblyLinearVelocity.X==12 and r.AssemblyLinearVelocity.Z==9)
        w.services.RunService.PreSimulation:Fire(1/60);assert(r.AssemblyLinearVelocity.Y==-120,'physical falling speed is preserved')
        w.services.RunService.PostSimulation:Fire(1/60)
        r.AssemblyLinearVelocity=w.env.Vector3.new(4,70,5);w.step();assert(r.AssemblyLinearVelocity.Y==70)
        local mover=w.env.Instance.new('LinearVelocity');mover.Name='HZFlightVelocity';mover.Parent=r
        r.AssemblyLinearVelocity=w.env.Vector3.new(140,-90,20);w.step();assert(r.AssemblyLinearVelocity.Y==-90)
        mover:Destroy();h.PlatformStand=true;w.step();assert(r.AssemblyLinearVelocity.Y==-90)
        h.PlatformStand=false;h.SeatPart={};w.step();assert(r.AssemblyLinearVelocity.Y==-90);h.SeatPart=nil
        local oldRoot=r
        char,h,r=w.character();r.AssemblyLinearVelocity=w.env.Vector3.new(3,-100,6);w.step()
        assert(r.AssemblyLinearVelocity.Y==0 and oldRoot.AssemblyLinearVelocity.Y==-90)
        releaseA();releaseA();assert(service.Parent and #service:GetChildren()==1)
        b:Destroy();w.step();assert(not service.Parent)
        assert(w.services.RunService.PreSimulation:Count()==0 and w.services.RunService.PostSimulation:Count()==0)
        releaseB()
    end)
    test('Flight respawn intent, late roots, repeated execution and owner cleanup',function()
        local w=world();local char,h,r=w.character()
        local owner=w.env.Instance.new('ScreenGui');owner.Parent=w.pg
        local controller=w.run(source.flight,{Owner=owner,ThemeSource=owner})
        local toggle=find(controller.Gui,'FlightToggle')
        toggle.Activated:Fire();w.step(3)
        assert(find(r,'HZFlightVelocity').Enabled and h.PlatformStand)
        h.Health=0;h.Died:Fire();w.step(3);assert(not r:FindFirstChild('HZFlightVelocity'))
        char,h,r=w.character();w.step(10)
        assert(r:FindFirstChild('HZFlightVelocity') and h.PlatformStand,'flight should resume on new body')
        local replacement=w.env.Instance.new('Part');replacement.Name='HumanoidRootPart';replacement.Size=w.env.Vector3.new(2,2,1)
        r:Destroy();w.step(2);replacement.Parent=char;w.step(12)
        assert(replacement:FindFirstChild('HZFlightVelocity'),'late replacement root should bind')
        toggle.Activated:Fire();w.step(2);assert(not replacement:FindFirstChild('HZFlightVelocity') and not h.PlatformStand)
        local again=w.run(source.flight,{Owner=owner});w.step(2)
        assert(not controller.Gui.Parent and again.Gui.Parent)
        owner:Destroy();w.step(3)
        assert(not again.Gui.Parent and not w.pg:FindFirstChild('HzReyzn_NoFallDamage_v4'))
        assert(w.services.RunService.PreSimulation:Count()==0)
    end)
    test('Hub default theme, selector, managed flight, motion compatibility and close',function()
        local w=world();local char,h,r=w.character()
        w.http['https://raw.githubusercontent.com/hzReyzn/scriptshz/main/HzReyzn_Halloween.client.lua']='return "completed"'
        w.http['https://raw.githubusercontent.com/hzReyzn/scriptshz/main/HzReyzn-Flight.lua']=source.flight
        w.run(source.hub);w.step(5)
        local gui=find(w.pg,'HzReyznInterface')
        assert(gui:GetAttribute('Theme')=='Halloween')
        assert(#w.requests==1 and w.requests[1]:find('Halloween'))
        find(gui,'Theme_Ocean Theme').Activated:Fire();w.step(2);assert(gui:GetAttribute('Theme')=='Ocean Theme')
        find(gui,'Toggle_nofall').Activated:Fire()
        find(gui,'Toggle_float').Activated:Fire()
        find(gui,'Toggle_water').Activated:Fire()
        find(gui,'AntiflingToggle').Activated:Fire()
        find(gui,'Fly SuperHero').Activated:Fire();w.step(5)
        local fly=assert(w.pg:FindFirstChild('HZFlightStandalone'))
        find(fly,'FlightToggle').Activated:Fire();w.step(5)
        local service=find(w.pg,'HzReyzn_NoFallDamage_v4');assert(#service:GetChildren()==2)
        find(gui,'Fly SuperHero').Activated:Fire();w.step(5);assert(w.pg:FindFirstChild('HZFlightStandalone')==fly)
        local frames=find(w.env.workspace,'HZLocalFloatFloors');assert(#frames:GetChildren()==0)
        r.AssemblyLinearVelocity=w.env.Vector3.new(190,130,0);w.step(2)
        assert(r.AssemblyLinearVelocity.X==190 and r.AssemblyLinearVelocity.Y==130)
        local window=find(gui,'Window');local minimize,close
        for _,o in ipairs(window:GetDescendants())do if o:IsA('TextButton') and o.Text=='−' and o.Size.X.Offset==36 then minimize=o;break end end
        local triggerColor=gui:GetAttribute('AccentColor')
        assert(minimize);minimize.Activated:Fire();w.step(30)
        assert(not window.Visible and find(gui,'HZLauncher').Visible)
        local flash=find(gui,'ThemeFlash')
        local edge=flash:FindFirstChildWhichIsA('UIStroke',true)
        local gradient=edge:FindFirstChildOfClass('UIGradient')
        assert(near(gradient.Color[1].R,triggerColor.R))
        local launcher=find(gui,'HZLauncher')
        local tap={UserInputType=w.env.Enum.UserInputType.Touch,Position=w.env.Vector3.new(50,50,0)}
        launcher.InputBegan:Fire(tap);w.services.UserInputService.InputEnded:Fire(tap);w.step(45)
        assert(window.Visible and not launcher.Visible)
        local close
        for _,o in ipairs(window:GetDescendants())do if o:IsA('TextButton') and o.Text=='×'then close=o;break end end
        assert(close);close.Activated:Fire();w.step(50)
        assert(not gui.Parent and not fly.Parent and not service.Parent)
        assert(w.services.RunService.PreSimulation:Count()==0 and w.services.RunService.RenderStepped:Count()==0)
    end)
    test('Compatible movie uses real frame sequence and original audio, then exits',function()
        local w=world();w.run(source.loader);w.step(35)
        local screen=find(w.pg,'HzReyznHalloweenLoading');local sound=find(screen,'OriginalMovieAudio')
        assert(screen:GetAttribute('PlaybackMode')=='Frames24')
        assert(not screen:FindFirstChildWhichIsA('VideoFrame',true),'no native video decoder dependency')
        assert(sound.SoundId:find('soundtrack') and not sound.Looped and sound.Volume>0)
        local frame=screen:GetAttribute('MovieFrame');assert(frame>0)
        w.step(90);assert(sound.Volume>.99 and screen:GetAttribute('MovieFrame')>frame)
        local last=screen:GetAttribute('MovieFrame')
        w.step(1000);assert(not screen.Parent and not sound.Parent)
        assert(w.services.RunService.Heartbeat:Count()==0 and #w.warnings==0)
    end)
    test('Movie owner cancellation removes images, audio and workers',function()
        local w=world();local owner=w.env.Instance.new('ScreenGui');owner.Parent=w.pg
        w.run(source.loader,{Owner=owner});w.step(90)
        local screen=find(w.pg,'HzReyznHalloweenLoading');local sound=find(screen,'OriginalMovieAudio')
        owner:Destroy();w.step(30)
        assert(not screen.Parent and not sound.Parent and sound.Volume==0)
        assert(w.services.RunService.Heartbeat:Count()==0)
    end)
    test('Hub waits for movie and retires the previous movie on re-execution',function()
        local w=world();w.character()
        w.http['https://raw.githubusercontent.com/hzReyzn/scriptshz/main/HzReyzn_Halloween.client.lua']=source.loader
        w.run(source.hub);w.step(60)
        local old=find(w.pg,'HzReyznInterface');local oldScreen=find(w.pg,'HzReyznHalloweenLoading')
        assert(not find(old,'Window').Visible)
        w.run(source.hub);w.step(90)
        assert(not old.Parent and not oldScreen.Parent)
        local gui=find(w.pg,'HzReyznInterface');assert(not find(gui,'Window').Visible)
        w.step(1080);assert(find(gui,'Window').Visible and not w.pg:FindFirstChild('HzReyznHalloweenLoading'))
        gui:Destroy();w.step(10)
        assert(w.services.RunService.Heartbeat:Count()==0 and w.services.RunService.RenderStepped:Count()==0)
        assert(#w.warnings==0,table.concat(w.warnings,'\n'))
    end)
    test('Unavailable media cannot leave an opaque loading screen',function()
        for _,mode in ipairs({'unsupported','network'}) do
            local w=world();w.character()
            if mode=='unsupported' then w.env.getcustomasset=nil else w.env.isfile=function() return false end end
            w.http['https://raw.githubusercontent.com/hzReyzn/scriptshz/main/HzReyzn_Halloween.client.lua']=source.loader
            w.run(source.hub);w.step(120)
            assert(find(w.pg,'Window').Visible and not w.pg:FindFirstChild('HzReyznHalloweenLoading'))
            assert(#w.warnings>=1)
        end
    end)
    test('Buffering keeps the previous atlas visible and pauses audio',function()
        local w=world();w.localStatusFalse=true
        w.services.ContentProvider.PreloadAsync=function(_,objects)
            if objects[1].Image and objects[1].Image:find('_005.jpg') then w.env.task.wait(3) end
        end
        w.run(source.loader);w.step(100)
        local screen=find(w.pg,'HzReyznHalloweenLoading');local audio=find(screen,'OriginalMovieAudio')
        assert(screen:GetAttribute('PlaybackStatus')=='buffering')
        assert(not audio.IsPlaying,'audio must pause while the next atlas loads')
        local held=screen:GetAttribute('MovieFrame')
        local shown
        for _,o in ipairs(screen:GetDescendants()) do
            if o:IsA('ImageLabel') and o.ImageTransparency<.1 then shown=o end
        end
        assert(shown and shown.Image:find('_004.jpg'),'hold atlas 4 while atlas 5 is pending')
        local image=shown.Image;w.step(30)
        assert(shown.Image==image and shown.ImageTransparency<.1 and screen:GetAttribute('MovieFrame')==held)
        w.step(170);assert(screen:GetAttribute('MovieFrame')>held and audio.IsPlaying)
        screen:Destroy();w.step(10)
        assert(not audio.Parent and w.services.RunService.Heartbeat:Count()==0)
    end)
    test('Artwork, all four logos, fluid motion and settings-controlled pause',function()
        local w=world();w.character()
        w.http['https://raw.githubusercontent.com/hzReyzn/scriptshz/main/HzReyzn_Halloween.client.lua']='return "completed"'
        w.run(source.hub);w.step(45)
        local gui=find(w.pg,'HzReyznInterface');local art=find(gui,'CemeteryArtwork')
        assert(art.Image:find('cemetery%-background'))
        local count=0
        for _,o in ipairs(gui:GetDescendants()) do
            if o.Name=='HalloweenLogo' then count+=1;assert(o.Visible and o.Image:find('hz%-logo')) end
        end
        assert(count==4)
        local ember=find(gui,'Ember1');local before=ember.Position.Y.Offset
        w.step(15);assert(before~=ember.Position.Y.Offset,'motion must run without repeated theme painting')
        find(gui,'AnimatedAccents').Activated:Fire();w.step(1)
        before=ember.Position.Y.Offset;local x=art.Position.X.Offset
        w.step(60);assert(before==ember.Position.Y.Offset and x==art.Position.X.Offset)
        find(gui,'Theme_Ocean Theme').Activated:Fire();w.step(2)
        assert(not find(gui,'HalloweenBackdrop').Visible and not find(gui,'HalloweenLogo').Visible)
        find(gui,'Theme_Halloween').Activated:Fire();w.step(2)
        assert(find(gui,'HalloweenBackdrop').Visible and find(gui,'HalloweenLogo').Visible)
        find(gui,'AnimatedAccents').Activated:Fire();w.step(15)
        assert(before~=ember.Position.Y.Offset)
        gui:Destroy();w.step(5);assert(w.services.RunService.RenderStepped:Count()==0)
    end)
    test('Compatible playback tolerates delayed local-asset IsLoaded flags',function()
        local w=world();w.localStatusFalse=true;w.character()
        w.http['https://raw.githubusercontent.com/hzReyzn/scriptshz/main/HzReyzn_Halloween.client.lua']=source.loader
        w.run(source.hub);w.step(90)
        local screen=find(w.pg,'HzReyznHalloweenLoading')
        assert(screen:GetAttribute('MovieFrame')>15)
        w.step(1100)
        local gui=find(w.pg,'HzReyznInterface');assert(find(gui,'Window').Visible)
        assert(find(gui,'HalloweenLogo').Visible)
        assert(#w.warnings==0,table.concat(w.warnings,'\n'))
        gui:Destroy();w.step(10)
    end)
    print(tostring(passed)..' behavioral scenarios passed (mock engine; in-game verification required).')
end
return runTests
