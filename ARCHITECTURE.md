# DuckNetKit - Architecture

Global namespace: `DuckNetKit`. Pure infrastructure addon, no UI, no gameplay, it only exists to be used by other addons when they need to send large net messages.

## Why this addon exists

Three other GMod addons from the same author hit the same problem at some point: the engine's ~64KB limit per net message, combined with the reliable buffer overflow (which disconnects the client) when several addons send traffic to the same player in the same tick. Each addon solved it differently:

- A per-player send queue with throttling based on `rate`/`sv_maxrate`. The most mature of the three, and the base this addon's send queue was generalized from.
- Manual chunking for one specific sync message, with no queue and no throttle.
- No chunking at all: just a size guard that gives up and logs a warning if the payload is too big. An image between 64KB and 250KB base64-encoded falls straight into that guard.

Each one reimplementing (or not implementing) the same thing is the problem this addon solves: a single, generic library any addon can call `DuckNetKit.Send` / `DuckNetKit.Receive` on, without thinking about the channel limit, compression, or reassembly.

## Load order

```
sh_core.lua        -- namespace, version, logger, config (chunk size, rate)
sh_codec.lua        -- serialization + compression, pure (no net.*)
sh_wire.lua         -- chunk wire format (WriteChunk/ReadChunk)
sh_register.lua     -- Register (AddNetworkString) + Receive (reassembly)
server/sv_send.lua  -- Send/Broadcast: per-player queue + throttle
client/cl_send.lua  -- SendToServer: single queue, fixed delay
```

`sh_codec.lua` and `sh_wire.lua` don't touch `net.*` beyond what's unavoidable (WriteUInt/WriteData/ReadUInt/ReadData), which made it possible to test the entire logic (chunk splitting, flags, compression fallback, reassembly) outside GMod by stubbing those calls, done before considering the library ready (see the testing section).

Both `autorun` loaders (`lua/autorun/server/duck_netkit_loader.lua` and the client one) fire `hook.Run("DuckNetKit.Ready")` and set `DuckNetKit.IsReady = true` after including every file for that realm. See the "Readiness hook" section below.

## API

```lua
-- register (optional, Send/SendToServer/Receive already call this internally)
DuckNetKit.Register("MyAddon.Catalog")

-- server -> one player or a list of players
DuckNetKit.Send("MyAddon.Catalog", ply, { items = {...} })
DuckNetKit.Send("MyAddon.Catalog", { ply1, ply2 }, payload)

-- server -> everyone (with an optional exclusion list)
DuckNetKit.Broadcast("MyAddon.Announce", payload, nil, { plyWhoTriggeredIt })

-- client -> server
DuckNetKit.SendToServer("MyAddon.RequestCatalog", payload)

-- receive (works on both realms, ply is nil on the client)
DuckNetKit.Receive("MyAddon.Catalog", function(payload, ply)
    -- payload already arrives decoded (a table or a string, depending on what was sent)
end)
```

`payload` can be a Lua table (sent as JSON) or a string (sent raw, useful for a binary blob that's already encoded, like an image). `opts` accepts `compress` (defaults to `true`, pass `false` to skip it, used when the payload is already compressed binary, e.g. an image, to avoid spending CPU trying to compress something that won't shrink) and `chunkSize` (defaults to 12000, see below).

## Where `ChunkSize = 12000` comes from

The engine's real limit is per message (close to 64KB), but the server sends net messages from MANY addons to the same client in the same tick, and the overflow that disconnects the player ("overflowed reliable channel") is about the *accumulated* buffer, not just one individual message. 12000 bytes per chunk is the value already validated in production by the sibling addon this code was generalized from, reused here instead of picking a "nicer" number without that validation.

## Overhead cut on purpose

- **No size field per chunk.** The chunk is always the last field written in the message, and every field before it (`index`, `total`, `flags`) is a multiple of 8 bits, so `net.BytesLeft()` on read gives the exact size without needing to send it again.
- **`flags` only goes on chunk 0.** Compression and format apply to the whole stream, not per chunk, repeating it on every chunk would be exactly the overhead this library exists to cut. `index` (16 bits) + `total` (16 bits) are the only header fields on chunks after the first.
- **Compression is attempted and compared, never assumed.** `sh_codec.lua` calls `util.Compress` and only uses the result if it actually ended up smaller than the raw payload. A small payload where zlib's overhead loses to the original size automatically falls back to the uncompressed path (one less flag bit for the other side to decode, and no `Decompress` call spent for nothing).
- **A payload that fits in one chunk doesn't pay for the stream protocol** beyond the minimal 5-byte header (`index=0` + `total=1` + `flags`). There's no separate "no-chunk mode" because the overhead difference between the two paths would be a few bytes, not worth the complexity of maintaining two message formats.

## Per-player queue (server) / single queue (client)

Every `DuckNetKit.Send` to the same player lands in the SAME queue, regardless of the net string or who called it. Two large sends to the same client at the same time can't inject into the network together, that would double the effective rate and overflow the reliable buffer even with each one individually "paused" (this was exactly the bug that existed before the sibling addon's send queue was written). The throttle uses the player's `rate` (clamped by `sv_maxrate`).

The client only has one possible destination (the server), so it's a single queue with no rate throttle, just a small fixed delay (`ClientChunkDelay`) between chunks, because client-to-server requests are typically small (never a full catalog or an entire image).

## Reassembly and concurrent streams

`sh_register.lua` keeps the reassembly buffer keyed by `net string` + sender key (the player's `UserID()` on the server, a fixed key on the client since there's only one possible sender there, the server). This lets two different players send chunks on the same net string at the same time without one contaminating the other's buffer, covered by the concurrent-streams test.

Relying on the reliable channel's guaranteed order (chunk 0 always arrives before chunk 1) is what avoids needing a stream/generation ID in the header: the sender's queue guarantees every chunk of a `DuckNetKit.Send` finishes being sent before the next one starts for the same player, so there's never more than one stream in flight per `(net string, sender)` at the same time.

## Readiness hook

GMod loads every addon's `autorun` scripts mixed together, with no guarantee that `duck_netkit` loads before whoever is going to use it. `DuckNetKit` itself only defines functions, it never executes any of them at the top level of a file, so it only needs to exist by the time the addon using it actually *calls* something (a player join, another hook, etc.), which in practice is always true, since every addon loads before the first player connects.

Still, anyone who wants to do something exactly at the moment `duck_netkit` finishes loading (for example, registering several net strings at once in a setup file) has two options:

```lua
-- option 1: hook directly
hook.Add("DuckNetKit.Ready", "MyAddon.Setup", function()
    -- DuckNetKit is guaranteed ready here
end)

-- option 2: DuckNetKit.OnReady, covers both load-order cases (if duck_netkit
-- already loaded before your addon, it calls right away; otherwise it
-- registers on the hook) without your addon needing to know which one happened
DuckNetKit.OnReady(function()
    -- same as above
end)
```

The hook fires once per realm (the server loader fires it server-side, the client loader fires it client-side) after including SHARED plus that realm's own files. `DuckNetKit.IsReady` becomes `true` at the same moment, for anyone who'd rather check the flag directly instead of using a hook.

## Tests

The pure logic (codec, chunk splitting, wire format, reassembly, concurrent streams, and both send queues end to end) was validated outside GMod with a plain Lua harness that stubs `net.*`/`util.*` enough to run the real flow of `DuckNetKit.Send` -> queue -> `net.Receive` -> reassembly. It doesn't replace testing inside a real GMod server (the harness doesn't run real `util.Compress`/`Decompress` when the Lua zlib binding isn't available locally), but it did catch a real simulation bug (`istable()` on a Player mock) before any addon depended on this code.
