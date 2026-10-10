DuckNetKit = DuckNetKit or {}
DuckNetKit.Loader = DuckNetKit.Loader or {}

local BASE = "duck_netkit/"

DuckNetKit.Loader.SHARED_FILES = {
    "shared/sh_core.lua",
    "shared/sh_codec.lua",
    "shared/sh_wire.lua",
    "shared/sh_register.lua",
}

DuckNetKit.Loader.SERVER_FILES = {
    "server/sv_send.lua",
}

DuckNetKit.Loader.CLIENT_FILES = {
    "client/cl_send.lua",
}

local function loadOne(path, realm)
    local ok, err = true, nil

    if realm == "shared" then
        if SERVER then AddCSLuaFile(path) end
        ok, err = pcall(include, path)
    elseif realm == "server" then
        if SERVER then
            ok, err = pcall(include, path)
        else
            ok = false
        end
    elseif realm == "client" then
        if SERVER then
            AddCSLuaFile(path)
            ok = true
        else
            ok, err = pcall(include, path)
        end
    end

    if not ok then
        print("[ERRO] duck_netkit: falha ao carregar " .. path .. " - " .. tostring(err))
    end
end

function DuckNetKit.Loader.Run(list, realm)
    for _, f in ipairs(list) do
        loadOne(BASE .. f, realm)
    end
end
