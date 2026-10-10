DuckNetKit = DuckNetKit or {}
DuckNetKit.Version = "1.0.0"

DuckNetKitLogger = DuckNetKitLogger or {}

function DuckNetKitLogger.debug(msg)
    if DuckNetKit.Config.Debug then
        print("[DuckNetKit] " .. msg)
    end
end

function DuckNetKitLogger.warn(msg)
    print("[DuckNetKit] AVISO: " .. msg)
end

DuckNetKit.Config = {
    Debug            = false,
    ChunkSize        = 12000,
    MinBytesPerSec   = 10000,
    MaxBytesPerSec   = 60000,
    RateFraction     = 0.3,
    FallbackRate     = 50000,
    ClientChunkDelay = 0.03,
}

DuckNetKit.FLAG_COMPRESSED = 1
DuckNetKit.FLAG_TABLE      = 2

DuckNetKit.IsReady = false

function DuckNetKit.OnReady(callback)
    if DuckNetKit.IsReady then
        callback()
        return
    end

    hook.Add("DuckNetKit.Ready", callback, callback)
end
