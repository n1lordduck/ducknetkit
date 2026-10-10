include("duck_netkit/sh_loader.lua")

DuckNetKit.Loader.Run(DuckNetKit.Loader.SHARED_FILES, "shared")
DuckNetKit.Loader.Run(DuckNetKit.Loader.CLIENT_FILES, "client")

DuckNetKit.IsReady = true
hook.Run("DuckNetKit.Ready")

print("[OK] duck_netkit: cliente carregado v" .. DuckNetKit.Version)
