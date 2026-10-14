-- Shared source embedded in Hub and the standalone intro; no extra module download.
local function createHalloweenMedia(isAlive)
    local base = "https://raw.githubusercontent.com/hzReyzn/scriptshz/main/assets/halloween/"
    local specs = {
        background = {file="cemetery-background-v1.jpg", bytes=267109, signature="\255\216\255"},
        logo = {file="hz-logo-v1.jpg", bytes=514147, signature="\255\216\255"},
        video = {file="intro-v1.webm", bytes=4176555, signature="\26\69\223\163"},
        videoFallback = {file="intro-v1.mp4", bytes=7042195, signature="ftyp", offset=5},
    }
    local resolved = {}
    local function valid(bytes, spec)
        local start = spec.offset or 1
        return type(bytes)=="string" and #bytes==spec.bytes
            and bytes:sub(start,start+#spec.signature-1)==spec.signature
    end
    return function(key)
        if not isAlive() then return "" end
        if resolved[key] then return resolved[key] end
        local spec = specs[key]
        local register = getcustomasset or getsynasset
        if not spec or type(register)~="function" or type(writefile)~="function" then return "" end
        local path = "HzReyzn_"..spec.file
        local exists = false
        if type(isfile)=="function" then
            local ok, found = pcall(isfile,path)
            exists = ok and found==true
        end
        if exists and type(readfile)=="function" then
            local ok, bytes = pcall(readfile,path)
            exists = ok and valid(bytes,spec)
        end
        if not exists then
            -- Bound the wait; a late HTTP response cannot write after cancellation.
            local pending, body, failed = true, nil, false
            task.spawn(function()
                local ok, data = pcall(function() return game:HttpGet(base..spec.file) end)
                if not pending or not isAlive() then return end
                if ok and valid(data,spec) then body=data else failed=true end
                pending=false
            end)
            local deadline=os.clock()+18
            while pending and isAlive() and os.clock()<deadline do task.wait(.05) end
            pending=false
            if failed or not body or not isAlive() then return "" end
            local ok=pcall(writefile,path,body)
            if not ok then return "" end
        end
        if not isAlive() then return "" end
        local ok, uri=pcall(register,path)
        if ok and type(uri)=="string" and uri~="" then resolved[key]=uri;return uri end
        return ""
    end
end
