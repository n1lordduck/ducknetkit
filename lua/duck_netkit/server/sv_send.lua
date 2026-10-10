local _queues   = {}
local _draining = {}

local function throttleBytesPerSec(ply)
    local cfg = DuckNetKit.Config

    local rate = ply:GetInfoNum("rate", 0)
    if not rate or rate <= 0 then rate = cfg.FallbackRate end

    local maxRate = GetConVar("sv_maxrate"):GetInt()
    if maxRate and maxRate > 0 then
        rate = math.min(rate, maxRate)
    end

    return math.Clamp(rate * cfg.RateFraction, cfg.MinBytesPerSec, cfg.MaxBytesPerSec)
end

local function drainQueue(ply)
    if not IsValid(ply) then
        _queues[ply], _draining[ply] = nil, nil
        return
    end

    local queue = _queues[ply]
    local job = queue and table.remove(queue, 1)
    if not job then
        _queues[ply], _draining[ply] = nil, nil
        return
    end

    net.Start(job.netString)
    DuckNetKit.WriteChunk(job.index, job.total, job.flags, job.chunk)
    net.Send(ply)

    local delay = math.max(0.04, #job.chunk / throttleBytesPerSec(ply))
    timer.Simple(delay, function()
        drainQueue(ply)
    end)
end

local function queueChunks(ply, netString, chunks, flags)
    _queues[ply] = _queues[ply] or {}
    local queue = _queues[ply]

    for i, chunk in ipairs(chunks) do
        queue[#queue + 1] = {
            netString = netString,
            index     = i - 1,
            total     = #chunks,
            flags     = flags,
            chunk     = chunk,
        }
    end

    if not _draining[ply] then
        _draining[ply] = true
        drainQueue(ply)
    end
end

local function resolveTargets(target)
    if istable(target) then return target end
    if IsValid(target) then return { target } end
    return nil
end

function DuckNetKit.Send(netString, target, payload, opts)
    DuckNetKit.Register(netString)

    local targets = resolveTargets(target)
    if not targets then
        DuckNetKitLogger.warn("DuckNetKit.Send chamado com destino invalido para '" .. netString .. "'")
        return
    end

    local bytes, flags = DuckNetKit.Encode(payload, opts)
    local chunks = DuckNetKit.SplitIntoChunks(bytes, opts and opts.chunkSize)

    for _, ply in ipairs(targets) do
        if IsValid(ply) then
            queueChunks(ply, netString, chunks, flags)
        end
    end
end

function DuckNetKit.Broadcast(netString, payload, opts, except)
    local targets = player.GetHumans()

    if except and #except > 0 then
        local excluded = {}
        for _, ply in ipairs(except) do
            excluded[ply] = true
        end

        local filtered = {}
        for _, ply in ipairs(targets) do
            if not excluded[ply] then
                filtered[#filtered + 1] = ply
            end
        end
        targets = filtered
    end

    DuckNetKit.Send(netString, targets, payload, opts)
end
