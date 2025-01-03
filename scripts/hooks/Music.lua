---@diagnostic disable: duplicate-doc-field
---@class Music : Music
---
---@field volume number
---@field pitch number
---@field looping boolean
---
---@field started boolean
---
---@field target_volume number
---@field fade_speed number
---@field fade_callback fun(music:Music)|nil
---
---@field removed boolean
---
---@field current string|nil
---
---@field sources love.Source[]
---
---@overload fun() : Music
local Music = {}

local _handlers = {}

---@type metatable
local volumes_mt = {__index = function (t, k) return rawget(t, 2) or ((t == 1 or t == "Default") and 1 or 0) end}

function Music:init()
    self.volume = 1

    self.pitch = 1
    self.looping = true

    self.started = false

    self.target_volume = 0
    self.fade_speed = 0
    self.fade_callback = nil

    self.removed = false

    self.current = nil
    self.sources = {}
    self.volumes = setmetatable({}, volumes_mt)
    self.target_volumes = setmetatable({}, volumes_mt)
end


---@param to? number
---@param speed? number
---@param callback? fun(music:Music)
function Music:fade(to, speed, callback)
    self.target_volume = to or 0
    self.fade_speed = speed or (10/30)
    self.fade_callback = callback
end

---@param to? number|number[]
---@param speed? number
---@param callback? fun(music:Music)
function Music:fadeAll(to, speed, callback)
    local vol = type(to) == "table" and to or {to or 0, 0}
    for i,v in pairs(vol) do
        self.target_volumes[i] = vol[i]
    end
    self.fade_speed = speed or (10/30)
    self.fade_callback = callback
end

---@param id number
---@return number
function Music:getVolume(id)
    return self.volume * MUSIC_VOLUME * (self.current and MUSIC_VOLUMES[self.current] or 1) * (self.volumes[id or 1] or 1)
end

---@return number
function Music:getPitch()
    return self.pitch * (self.current and MUSIC_PITCHES[self.current] or 1)
end

---@param music? string
---@param volume? number
---@param pitch? number
function Music:play(music, volume, pitch)
    if music then
        local musics = {music}
        -- TODO: More flexible/sensible naming scheme
        local function loadMultiTrack(format)
            musics = {format:format(music, 1)}
            for i=1,1000 do -- Probably enough
                local path = Assets.getMusicPath(format:format(music, i))
                if not path then break end
                musics[i] = format:format(music, i)
            end
        end
        if love.filesystem.getInfo(Mod.info.path.."/assets/music/"..music, "directory") then
            musics = {}
            for _,v in ipairs(love.filesystem.getDirectoryItems(Mod.info.path.."/assets/music/"..music)) do
                _, v = Utils.endsWith(v, ".wav")
                musics[v] = Assets.getMusicPath(music.."/"..v)
            end
            Kristal.Console.env.print("musics",musics)
        elseif Assets.getMusicPath(music..".1") and false then
            loadMultiTrack("%s .%i")
        elseif Assets.getMusicPath(music.." - Track 1") then
            loadMultiTrack("%s - Track %i")
        end
        local paths = {}
        for i,v in pairs(musics) do
            paths[i] = Assets.getMusicPath(v) or v
        end
        Kristal.Console.env.print(paths)
        self:playFile(paths, volume, pitch, music)
    else
        self:playFile(nil, volume, pitch)
    end
end

---@param path? string|string[]
---@param volume? number
---@param pitch? number
---@param name? string
function Music:playFile(path, volume, pitch, name)
    if self.removed then
        return
    end

    self.fade_speed = 0

    if path then
        if type(path) == "string" then
            path = {path}
        end
        name = name or path[1]
        if volume then
            self.volume = volume
        end
        if self.current ~= name or not self.source or not self:isPlaying() then
            for _,source in pairs(self.sources) do
                source:stop()
            end
            self.current = name
            self.pitch = pitch or 1
            self.sources = {}
            self.volumes = {1, Default = 1}
            self.target_volumes = {1, Default = 1}
            self.target_volume = 1
            for i, value in pairs(path) do
                self.sources[i] = (love.audio.newSource(value, "stream"))
                self.volumes[i] = self.volumes[i] or 1
                self.target_volumes[i] = self.target_volumes[i] or 0
            end
            for id,source in pairs(self.sources) do
                Kristal.Console.env.print("source",id,source)
                source:setVolume(self:getVolume(id))
                source:setPitch(self:getPitch())
                source:setLooping(self.looping)
                source:play()
            end
            self.started = true
        else
            if volume then
                self.volume = volume
                for _,source in pairs(self.sources) do
                    source:setVolume(self:getVolume())
                end
            end
            if pitch then
                self.pitch = pitch
                for _,source in pairs(self.sources) do
                    source:setPitch(self:getPitch())
                end
            end
        end
    elseif self.source then
        if volume then
            self.volume = volume
            for id,source in pairs(self.sources) do
                source:setVolume(self:getVolume(id))
            end
        end
        if pitch then
            self.pitch = pitch
            for _,source in pairs(self.sources) do
                source:setPitch(self:getPitch())
            end
        end
        for _,source in pairs(self.sources) do
            source:play()
        end
        self.started = true
    end
end

---@param volume number
function Music:setVolume(volume)
    self.volume = volume
    for id,source in pairs(self.sources) do
        source:setVolume(self:getVolume(id))
    end
end

---@param pitch number
function Music:setPitch(pitch)
    self.pitch = pitch
    for _,source in pairs(self.sources) do
        source:setPitch(self:getPitch())
    end
end

---@param loop boolean
function Music:setLooping(loop)
    self.looping = loop
    for _,source in pairs(self.sources) do
        source:setLooping(loop)
    end
end

---@param time number
function Music:seek(time)
    for _,source in pairs(self.sources) do
        source:seek(time)
    end
end

function Music:getSource()
    return self.sources[1] or self.sources["Default"]
end

---@return number
function Music:tell()
    return self:getSource():tell()
end

function Music:stop()
    self.fade_speed = 0
    for _,source in pairs(self.sources) do
        source:stop()
    end
    self.started = false
end

function Music:pause()
    for _,source in pairs(self.sources) do
        source:pause()
    end
    self.started = false
end

function Music:resume()
    for _,source in pairs(self.sources) do
        source:play()
    end
    self.started = true
end

---@return boolean
function Music:isPlaying()
    return self:getSource() and self:getSource():isPlaying() or false
end

---@return boolean
function Music:canResume()
    return self:getSource() ~= nil and not self:getSource():isPlaying()
end

function Music:remove()
    Utils.removeFromTable(_handlers, self)
    for _,source in pairs(self.sources) do
        source:stop()
    end
    self.sources = {}
    self.started = false
    self.removed = true
end

-- Static Functions

local function getAll()
    return _handlers
end

local function getPlaying()
    local result = {}
    for _,handler in ipairs(_handlers) do
        if handler.source and handler.source:isPlaying() then
            table.insert(result, handler)
        end
    end
    return result
end

local function stop()
    for _,handler in ipairs(_handlers) do
        if handler.source and handler.source:isPlaying() then
            handler.source:stop()
        end
    end
end

local function clear()
    for _,handler in ipairs(_handlers) do
        if handler.source then
            handler.source:stop()
        end
    end
    _handlers = {}
end

local function update()
    for _,handler in ipairs(_handlers) do

        local fade = nil
        for id, source in pairs(handler.sources) do
            if handler.volumes[id] ~= (handler.target_volumes[id] * handler.target_volume) then
                fade = fade or "finished"
                handler.volumes[id] = Utils.approach(handler.volumes[id], (handler.target_volumes[id] * handler.target_volume), DT / handler.fade_speed)
                if handler.volumes[id] ~= (handler.target_volumes[id] * handler.target_volume) then
                    fade = "unfinished"
                end
            end
            local volume = handler:getVolume(id)
            if source:getVolume() ~= volume then
                source:setVolume(volume)
            end
            local pitch = handler:getPitch()
            if source:getPitch() ~= pitch then
                source:setPitch(pitch)
            end
        end
        if fade == "finished" then
            handler.fade_speed = 0
            if handler.fade_callback then
                handler:fade_callback()
            end
        end
    end
end

local function new(music, volume, pitch)
    local handler = setmetatable({}, {__index = Music})

    table.insert(_handlers, handler)
    handler:init()

    if music then
        handler.current = music
        handler.volume = volume or 1
        handler.pitch = pitch or 1
        handler:play(music, volume, pitch)
    end

    return handler
end

local module = {
    new = new,
    update = update,
    clear = clear,
    stop = stop,
    getAll = getAll,
    getPlaying = getPlaying,
    lib = Music,
}

return setmetatable(module, {__call = function(t, ...) return new(...) end})