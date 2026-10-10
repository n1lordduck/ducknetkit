local FLAG_COMPRESSED = DuckNetKit.FLAG_COMPRESSED
local FLAG_TABLE      = DuckNetKit.FLAG_TABLE

function DuckNetKit.Encode(payload, opts)
    opts = opts or {}

    local flags = 0
    local raw

    if istable(payload) then
        raw = util.TableToJSON(payload)
        flags = bit.bor(flags, FLAG_TABLE)
    else
        raw = tostring(payload)
    end

    if opts.compress == false then
        return raw, flags
    end

    local compressed = util.Compress(raw)
    if compressed and #compressed < #raw then
        return compressed, bit.bor(flags, FLAG_COMPRESSED)
    end

    return raw, flags
end

function DuckNetKit.Decode(bytes, flags)
    local raw = bytes

    if bit.band(flags, FLAG_COMPRESSED) ~= 0 then
        raw = util.Decompress(bytes)
        if not raw then return nil end
    end

    if bit.band(flags, FLAG_TABLE) ~= 0 then
        return util.JSONToTable(raw)
    end

    return raw
end

function DuckNetKit.SplitIntoChunks(bytes, chunkSize)
    chunkSize = chunkSize or DuckNetKit.Config.ChunkSize

    local total = math.max(1, math.ceil(#bytes / chunkSize))
    local chunks = {}

    for i = 0, total - 1 do
        local startPos = i * chunkSize + 1
        chunks[i + 1] = string.sub(bytes, startPos, startPos + chunkSize - 1)
    end

    return chunks
end
