# DuckNetKit

<p align="center">
  <img src="https://img.shields.io/badge/language-Lua-blue?style=for-the-badge&logo=lua">
  <img src="https://img.shields.io/badge/status-in%20development-yellow?style=for-the-badge">
  <a href="https://github.com/n1lordduck/ducknetkit/actions/workflows/tests.yml"><img src="https://img.shields.io/github/actions/workflow/status/n1lordduck/ducknetkit/tests.yml?branch=main&label=tests&style=for-the-badge"></a>
  <a href="https://github.com/n1lordduck/ducknetkit/actions/workflows/lint.yml"><img src="https://img.shields.io/github/actions/workflow/status/n1lordduck/ducknetkit/lint.yml?branch=main&label=lint&style=for-the-badge"></a>
  <img src="https://img.shields.io/badge/license-MIT-green?style=for-the-badge">
  <img src="https://img.shields.io/badge/platform-GMod-lightgrey?style=for-the-badge">
</p>

A small networking library for Garry's Mod. It automatically chunks, compresses, and rate-limits net messages so you never have to think about the engine's 64KB channel limit or write your own reassembly code again.

## Features

- Automatic chunking: any payload (a Lua table or a string) gets cut into pieces that stay well under the 64KB per-message limit, with a per-player send queue so chunks from different sends never interleave.
- Compression is attempted and compared, never assumed. If `util.Compress` doesn't actually shrink the payload, it's sent raw instead, so you never pay the zlib overhead on small messages.
- Rate-aware throttling on the server side, based on each player's `rate` convar (clamped by `sv_maxrate`), to avoid overflowing the reliable channel when sending to many players at once.
- Minimal wire overhead: no redundant length field per chunk (uses `net.BytesLeft()`), and the compression/format flag byte is only sent once per stream, not once per chunk.
- A `DuckNetKit.Ready` hook (and a `DuckNetKit.OnReady` helper) so other addons can safely hook into the library regardless of GMod's addon load order.
- Automatic cleanup of incomplete reassembly buffers on player disconnect.

## Installation

Clone (or download and extract) this repository into your server's `garrysmod/addons/` folder. The `lua/` folder needs to sit directly at the addon's root.

```bash
git clone https://github.com/n1lordduck/ducknetkit.git garrysmod/addons/duck_netkit
```

## Usage

```lua
-- server
DuckNetKit.Receive("MyAddon.RequestData", function(payload, ply)
    DuckNetKit.Send("MyAddon.Data", ply, { items = MyAddon.GetItems(ply) })
end)

-- client
DuckNetKit.Receive("MyAddon.Data", function(payload)
    PrintTable(payload.items)
end)

DuckNetKit.SendToServer("MyAddon.RequestData", {})
```

No manual registration needed: `Send`, `SendToServer`, and `Receive` register the net string for you the first time they're called with a given name.

See [ARCHITECTURE.md](./ARCHITECTURE.md) for how the wire format, reassembly, and send queue actually work.

## Directory Structure

* `lua/duck_netkit/shared` - serialization, compression, the wire format, and the reassembly logic (`sh_codec.lua`, `sh_wire.lua`, `sh_register.lua`), plus shared config (`sh_core.lua`).
* `lua/duck_netkit/server` - the per-player send queue and rate throttle (`sv_send.lua`).
* `lua/duck_netkit/client` - the client-side send queue (`cl_send.lua`).
* `lua/autorun` - the server and client entry points that load everything and fire `DuckNetKit.Ready`.
* `tests` - a standalone Lua test suite that stubs `net`/`util`/`hook` and exercises the library's logic outside GMod.
* `.github/workflows` - CI: `tests.yml` runs the test suite, `lint.yml` checks every file's Lua syntax (allowing GLua's `continue`, which isn't valid in vanilla Lua).

## License

This project is licensed under the MIT License - see [LICENSE](./LICENSE).
