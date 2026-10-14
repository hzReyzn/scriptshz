-- Shared NoFallDamage v4. One owner-counted controller for Hub and Fly.
-- No yielding inside physics callbacks, no saved velocity written to a new body.
-- Masks only downward velocity between physics steps, preserving normal fall motion.
-- Client-side behavior is game-dependent; this does not override server damage.
local function acquireNoFall(owner)
    if game.PlaceId ~= 189707 or not owner or not owner.Parent then return nil end
    local service = playerGui:FindFirstChild("HzReyzn_NoFallDamage_v4")
    if not service then
        service = Instance.new("Folder")
        service.Name = "HzReyzn_NoFallDamage_v4"
        local closed, pending = false, nil
        local links, leaseLinks = {}, {}
        local function hasOwners()
            for _, lease in ipairs(service:GetChildren()) do
                if lease:IsA("ObjectValue") and lease.Value and lease.Value.Parent then return true end
            end
            return false
        end
        local function unwatch(lease)
            local link = leaseLinks[lease]
            if link then link:Disconnect(); leaseLinks[lease] = nil end
        end
        local function watch(lease)
            if not lease:IsA("ObjectValue") or not lease.Value or leaseLinks[lease] then return end
            leaseLinks[lease] = lease.Value.Destroying:Connect(function()
                if lease.Parent then lease:Destroy() end
            end)
        end
        local function restore()
            local sample=pending;pending=nil
            if not sample then return end
            local r,h,c=sample.root,sample.humanoid,sample.character
            if player.Character~=c or c:FindFirstChild("HumanoidRootPart")~=r
                or not r.Parent or h.Health<=0 or h.PlatformStand or h.SeatPart or r.Anchored then return end
            local flight=r:FindFirstChild("HZFlightVelocity")
            if flight and flight.Enabled then return end
            local current=r.AssemblyLinearVelocity
            -- Restore only our unchanged sentinel. A jump, a mover or another controller wins.
            if current.Y==0 and h.FloorMaterial==Enum.Material.Air then
                r.AssemblyLinearVelocity=Vector3.new(current.X,sample.y,current.Z)
            end
        end
        local function stop()
            if closed then return end
            closed = true
            restore()
            for _, link in ipairs(links) do link:Disconnect() end
            for lease in pairs(leaseLinks) do unwatch(lease) end
            table.clear(links)
        end
        links[#links + 1] = service.Destroying:Connect(stop)
        links[#links + 1] = service.ChildAdded:Connect(watch)
        links[#links + 1] = service.ChildRemoved:Connect(function(lease)
            unwatch(lease)
            if not closed and service.Parent and not hasOwners() then service:Destroy() end
        end)
        local function step()
            if closed then return end
            if not hasOwners() then service:Destroy(); return end
            -- Resolve the current body every step: covers late roots, respawns and replacements.
            local character = player.Character
            local h = character and character:FindFirstChildOfClass("Humanoid")
            local r = character and character:FindFirstChild("HumanoidRootPart")
            if not h or not r or not r.Parent or h.Health <= 0 or r.Anchored
                or h.SeatPart or h.PlatformStand or h.Sit then return end
            local flight = r:FindFirstChild("HZFlightVelocity")
            if flight and flight.Enabled then return end
            local state = h:GetState()
            if state ~= Enum.HumanoidStateType.Freefall and state ~= Enum.HumanoidStateType.Jumping then return end
            local velocity = r.AssemblyLinearVelocity
            -- The next PreSimulation restores this Y before physics advances.
            -- No RenderStepped:Wait(), overlapping samples or horizontal velocity reset.
            if velocity.Y < -4 and not pending then
                pending={root=r,humanoid=h,character=character,y=velocity.Y}
                r.AssemblyLinearVelocity = Vector3.new(velocity.X, 0, velocity.Z)
            end
        end
        service.Parent = playerGui
        -- Retire old samplers before they can restore a stale velocity. Preserve their live leases.
        for _, name in ipairs({"HzReyzn_NoFallDamage_v2", "HzReyzn_NoFallDamage_v3"}) do
            local previous = playerGui:FindFirstChild(name)
            if previous then
                for _, lease in ipairs(previous:GetChildren()) do
                    if lease:IsA("ObjectValue") and lease.Value and lease.Value.Parent then
                        lease.Parent = service; watch(lease)
                    end
                end
                previous:Destroy()
            end
        end
        links[#links + 1] = RunService.PreSimulation:Connect(restore)
        links[#links + 1] = RunService.PostSimulation:Connect(step)
    end
    local lease = Instance.new("ObjectValue")
    lease.Name = owner.Name; lease.Value = owner; lease.Parent = service
    local released = false
    return function()
        if released then return end
        released = true
        if lease.Parent then lease:Destroy() end
    end
end
-- End shared NoFallDamage.
