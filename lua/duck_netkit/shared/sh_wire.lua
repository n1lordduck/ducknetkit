function DuckNetKit.WriteChunk(index, total, flags, data)
    net.WriteUInt(index, 16)
    net.WriteUInt(total, 16)

    if index == 0 then
        net.WriteUInt(flags, 8)
    end

    net.WriteData(data, #data)
end

function DuckNetKit.ReadChunk()
    local index = net.ReadUInt(16)
    local total = net.ReadUInt(16)

    local flags = nil
    if index == 0 then
        flags = net.ReadUInt(8)
    end

    local data = net.ReadData(net.BytesLeft())

    return index, total, flags, data
end
