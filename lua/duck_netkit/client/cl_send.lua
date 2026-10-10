local _queue    = {}
local _draining = false

local function drainQueue()
    local job = table.remove(_queue, 1)
    if not job then
        _draining = false
        return
    end

    net.Start(job.netString)
    DuckNetKit.WriteChunk(job.index, job.total, job.flags, job.chunk)
    net.SendToServer()

    timer.Simple(DuckNetKit.Config.ClientChunkDelay, drainQueue)
end

function DuckNetKit.SendToServer(netString, payload, opts)
    DuckNetKit.Register(netString)

    local bytes, flags = DuckNetKit.Encode(payload, opts)
    local chunks = DuckNetKit.SplitIntoChunks(bytes, opts and opts.chunkSize)

    for i, chunk in ipairs(chunks) do
        _queue[#_queue + 1] = {
            netString = netString,
            index     = i - 1,
            total     = #chunks,
            flags     = flags,
            chunk     = chunk,
        }
    end

    if not _draining then
        _draining = true
        drainQueue()
    end
end
