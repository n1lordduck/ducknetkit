DuckNetKit._registered = DuckNetKit._registered or {}
DuckNetKit._pending     = DuckNetKit._pending or {}

function DuckNetKit.Register(netString)
    if DuckNetKit._registered[netString] then return end
    DuckNetKit._registered[netString] = true

    if SERVER then
        util.AddNetworkString(netString)
    end
end

local function senderKey(ply)
    if SERVER then
        return IsValid(ply) and ply:UserID() or -1
    end
    return 0
end

function DuckNetKit.Receive(netString, callback)
    DuckNetKit.Register(netString)

    net.Receive(netString, function(_, ply)
        local index, total, flags, data = DuckNetKit.ReadChunk()
        local key = senderKey(ply)

        local byPlayer = DuckNetKit._pending[netString]
        if not byPlayer then
            byPlayer = {}
            DuckNetKit._pending[netString] = byPlayer
        end

        if index == 0 then
            byPlayer[key] = { total = total, flags = flags, chunks = {}, count = 0 }
        end

        local pending = byPlayer[key]
        if not pending then
            DuckNetKitLogger.warn("chunk fora de ordem em '" .. netString .. "', descartado")
            return
        end

        if not pending.chunks[index] then
            pending.chunks[index] = data
            pending.count = pending.count + 1
        end

        if pending.count < pending.total then return end

        byPlayer[key] = nil

        local parts = {}
        for i = 0, pending.total - 1 do
            parts[i + 1] = pending.chunks[i]
        end

        local payload = DuckNetKit.Decode(table.concat(parts), pending.flags)
        if payload == nil then
            DuckNetKitLogger.warn("falha ao decodificar payload de '" .. netString .. "'")
            return
        end

        callback(payload, ply)
    end)
end

if SERVER then
    hook.Add("PlayerDisconnected", "DuckNetKit.CleanupPending", function(ply)
        local id = ply:UserID()
        for _, byPlayer in pairs(DuckNetKit._pending) do
            byPlayer[id] = nil
        end
    end)
end
