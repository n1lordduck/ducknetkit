local ok_zlib, zlib = pcall(require, "zlib")

bit = {
    bor  = function(a, b) return a | b end,
    band = function(a, b) return a & b end,
}

SERVER = true
CLIENT = false

util = {}
function util.TableToJSON(tbl)
    local parts = {}
    for k, v in pairs(tbl) do
        local val
        if type(v) == "string" then val = string.format("%q", v)
        elseif type(v) == "table" then val = util.TableToJSON(v)
        else val = tostring(v) end
        parts[#parts + 1] = string.format('"%s":%s', k, val)
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

function util.JSONToTable(json)
    local result = {}
    for k, v in string.gmatch(json, '"(%w+)":"?([^",}]+)"?') do
        result[k] = tonumber(v) or v
    end
    return result
end

function util.Compress(raw)
    if ok_zlib then
        return zlib.deflate()(raw, "finish")
    end
    return raw .. raw
end

function util.Decompress(data)
    if ok_zlib then
        return zlib.inflate()(data, "finish")
    end
    return nil
end

local _networkStrings = {}
function util.AddNetworkString(name)
    _networkStrings[name] = true
end

local _rawType = type
function type(v)
    if _rawType(v) == "table" then
        local mt = getmetatable(v)
        if mt and mt.MetaName then return mt.MetaName end
    end
    return _rawType(v)
end

istable = function(v) return type(v) == "table" end

math.Clamp = function(v, lo, hi)
    if v < lo then return lo elseif v > hi then return hi end
    return v
end

local _writeBuf
local _readBuf, _readPos
local _receivers = {}

net = {}

function net.Start() _writeBuf = {} end

function net.WriteUInt(v, bits)
    local nbytes = bits / 8
    for i = nbytes - 1, 0, -1 do
        _writeBuf[#_writeBuf + 1] = string.char(math.floor(v / (256 ^ i)) % 256)
    end
end

function net.WriteData(data, len)
    for i = 1, len do
        _writeBuf[#_writeBuf + 1] = string.sub(data, i, i)
    end
end

local function dispatch(netString, ply)
    beginReadFromWriteBuf()
    local handler = _receivers[netString]
    assert(handler, "no net.Receive registered for " .. netString)
    handler(#_readBuf, ply)
end

function beginReadFromWriteBuf()
    _readBuf = table.concat(_writeBuf)
    _readPos = 1
end

function net.Send(ply) dispatch(net._currentString, ply) end
function net.SendToServer() dispatch(net._currentString, nil) end

local _realStart = net.Start
function net.Start(name)
    net._currentString = name
    _realStart()
end

function net.ReadUInt(bits)
    local nbytes = bits / 8
    local v = 0
    for _ = 1, nbytes do
        v = v * 256 + string.byte(_readBuf, _readPos)
        _readPos = _readPos + 1
    end
    return v
end

function net.BytesLeft()
    return #_readBuf - _readPos + 1
end

function net.ReadData(len)
    local s = string.sub(_readBuf, _readPos, _readPos + len - 1)
    _readPos = _readPos + len
    return s
end

function net.Receive(name, fn)
    _receivers[name] = fn
end

timer = { Simple = function(_, fn) fn() end }

local _hooks = {}
hook = {}
function hook.Add(event, id, fn)
    _hooks[event] = _hooks[event] or {}
    _hooks[event][id] = fn
end
function hook.Run(event, ...)
    for _, fn in pairs(_hooks[event] or {}) do
        fn(...)
    end
end
IsValid = function(ply) return ply ~= nil and ply.valid ~= false end
GetConVar = function() return { GetInt = function() return 0 end } end

local PLAYER_META = { MetaName = "Player" }
local function newPlayer(id)
    return setmetatable({
        valid = true,
        UserID = function() return id end,
        GetInfoNum = function() return 0 end,
    }, PLAYER_META)
end

local scriptDir = (arg and arg[0] or "tests/duck_netkit_spec.lua"):match("(.*/)") or "./"
local BASE = scriptDir .. "../lua/duck_netkit/"

local function loadFile(path)
    local chunk = assert(loadfile(BASE .. path))
    chunk()
end

loadFile("shared/sh_core.lua")
loadFile("shared/sh_codec.lua")
loadFile("shared/sh_wire.lua")
loadFile("shared/sh_register.lua")
loadFile("server/sv_send.lua")
loadFile("client/cl_send.lua")

local failures = 0
local function check(name, cond, detail)
    if cond then
        print("OK   " .. name)
    else
        failures = failures + 1
        print("FAIL " .. name .. (detail and (" -- " .. detail) or ""))
    end
end

do
    local payload = { a = 1 }
    local bytes, flags = DuckNetKit.Encode(payload)
    local back = DuckNetKit.Decode(bytes, flags)
    check("codec: small table round trip", back and back.a == 1, "got " .. tostring(back and back.a))
    check("codec: small table skipped compression", bit.band(flags, DuckNetKit.FLAG_COMPRESSED) == 0)
end

do
    local big = string.rep("duck_netkit_test_payload_", 2000)
    local bytes, flags = DuckNetKit.Encode(big)
    local back = DuckNetKit.Decode(bytes, flags)
    check("codec: large string round trip", back == big, "lengths " .. #back .. " vs " .. #big)
    if ok_zlib then
        check("codec: large string got compressed", bit.band(flags, DuckNetKit.FLAG_COMPRESSED) ~= 0)
        check("codec: compressed payload smaller than raw", #bytes < #big)
    else
        print("SKIP zlib not available locally - compression-path assertions skipped")
    end
end

do
    local big = string.rep("x", 5000)
    local bytes, flags = DuckNetKit.Encode(big, { compress = false })
    check("codec: compress=false skips compression", bit.band(flags, DuckNetKit.FLAG_COMPRESSED) == 0)
    check("codec: compress=false keeps bytes identical", bytes == big)
end

do
    local chunks = DuckNetKit.SplitIntoChunks(string.rep("a", 30), 10)
    check("split: exact multiple -> 3 chunks", #chunks == 3)

    chunks = DuckNetKit.SplitIntoChunks(string.rep("a", 25), 10)
    check("split: remainder -> 3 chunks, last is 5 bytes", #chunks == 3 and #chunks[3] == 5)

    chunks = DuckNetKit.SplitIntoChunks("", 10)
    check("split: empty payload -> 1 empty chunk", #chunks == 1 and chunks[1] == "")
end

do
    net.Start("Test.Wire")
    DuckNetKit.WriteChunk(0, 1, 7, "hello")
    beginReadFromWriteBuf()
    local index, total, flags, data = DuckNetKit.ReadChunk()
    check("wire: single chunk index", index == 0)
    check("wire: single chunk total", total == 1)
    check("wire: single chunk flags", flags == 7)
    check("wire: single chunk data", data == "hello")
end

do
    net.Start("Test.Wire")
    DuckNetKit.WriteChunk(1, 3, 99, "world")
    beginReadFromWriteBuf()
    local index, total, flags, data = DuckNetKit.ReadChunk()
    check("wire: continuation chunk index", index == 1)
    check("wire: continuation chunk total", total == 3)
    check("wire: continuation chunk has no flags", flags == nil)
    check("wire: continuation chunk data", data == "world")
end

do
    local received = nil
    DuckNetKit.Receive("Test.Multi", function(payload)
        received = payload
    end)

    local bigString = string.rep("ABCDEFGHIJ", 50)
    local bytes, flags = DuckNetKit.Encode(bigString, { compress = false })
    local chunks = DuckNetKit.SplitIntoChunks(bytes, 37)
    check("receive: payload actually got split into multiple chunks", #chunks > 1, "#chunks=" .. #chunks)

    local ply = newPlayer(1)
    for i, chunk in ipairs(chunks) do
        net.Start("Test.Multi")
        DuckNetKit.WriteChunk(i - 1, #chunks, flags, chunk)
        net.Send(ply)
        if i < #chunks then
            check("receive: no callback before last chunk (i=" .. i .. ")", received == nil)
        end
    end

    check("receive: full multi-chunk payload reassembled correctly", received == bigString)
end

do
    local resultsByPlayer = {}
    DuckNetKit.Receive("Test.Concurrent", function(payload, ply)
        resultsByPlayer[ply:UserID()] = payload
    end)

    local plyA, plyB = newPlayer(10), newPlayer(20)
    local payloadA = string.rep("A", 80)
    local payloadB = string.rep("B", 80)

    local bytesA = DuckNetKit.Encode(payloadA, { compress = false })
    local bytesB = DuckNetKit.Encode(payloadB, { compress = false })
    local chunksA = DuckNetKit.SplitIntoChunks(bytesA, 30)
    local chunksB = DuckNetKit.SplitIntoChunks(bytesB, 30)

    local maxLen = math.max(#chunksA, #chunksB)
    for i = 1, maxLen do
        if chunksA[i] then
            net.Start("Test.Concurrent")
            DuckNetKit.WriteChunk(i - 1, #chunksA, 0, chunksA[i])
            net.Send(plyA)
        end
        if chunksB[i] then
            net.Start("Test.Concurrent")
            DuckNetKit.WriteChunk(i - 1, #chunksB, 0, chunksB[i])
            net.Send(plyB)
        end
    end

    check("concurrent: player A payload correct", resultsByPlayer[10] == payloadA)
    check("concurrent: player B payload correct", resultsByPlayer[20] == payloadB)
end

do
    local received = nil
    DuckNetKit.Receive("Test.FullSend", function(payload)
        received = payload
    end)

    local ply = newPlayer(42)
    local payload = { msg = "hello from the queue", n = 123 }
    DuckNetKit.Send("Test.FullSend", ply, payload, { chunkSize = 8 })

    check("full send: table payload survives the real send queue", received and received.msg == "hello from the queue")
end

do
    local received = nil
    DuckNetKit.Receive("Test.ClientRequest", function(payload)
        received = payload
    end)

    local payload = string.rep("req-", 200)
    DuckNetKit.SendToServer("Test.ClientRequest", payload, { compress = false, chunkSize = 25 })

    check("client send: payload survives the real client queue", received == payload)
end

do
    DuckNetKit.IsReady = false
    local called = false
    DuckNetKit.OnReady(function() called = true end)
    check("onready: not called before DuckNetKit.Ready fires", called == false)

    hook.Run("DuckNetKit.Ready")
    check("onready: called once DuckNetKit.Ready fires", called == true)
end

do
    DuckNetKit.IsReady = true
    local called = false
    DuckNetKit.OnReady(function() called = true end)
    check("onready: called immediately when already ready", called == true)
end

print("")
if failures == 0 then
    print("ALL TESTS PASSED")
else
    print(failures .. " TEST(S) FAILED")
    os.exit(1)
end
