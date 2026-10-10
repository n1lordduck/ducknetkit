# AGENTS.md

Guidance for anyone (human or AI) writing code in this repo. The goal is a library other addons can trust blindly, not one that's clever.

## This is a wire protocol, not just a Lua API

`sh_wire.lua` defines the exact byte layout every chunk uses. Changing the order of fields, the bit width of `index`/`total`, or when `flags` gets written is a breaking change for anything already relying on it, not a refactor. If you touch `WriteChunk`/`ReadChunk`, both sides have to change together and the reasoning in `ARCHITECTURE.md` has to be updated to match.

- The chunk's data is always the last field written. `ReadChunk` relies on `net.BytesLeft()` to know its length instead of a redundant size field. Don't write anything after `net.WriteData` in `WriteChunk`.
- `flags` is only written on `index == 0`. Don't start writing it on every chunk "for consistency" - that's exactly the per-chunk overhead this library exists to avoid.

## The no-stream-id design is not an oversight

`sh_register.lua` reassembles chunks per `(netString, sender)` key with no stream/generation ID, because it relies on two guarantees holding at the same time: the GMod net channel is reliable and ordered, and the send queues (`sv_send.lua`, `cl_send.lua`) never let two sends to the same recipient interleave. If you ever change the queue to send chunks from different calls concurrently, or batch multiple payloads into one job, you've broken that assumption and `sh_register.lua` needs a real stream ID, not a patch on top.

## Config values are not placeholders

`ChunkSize = 12000` in `sh_core.lua` isn't a guess. It was carried over from a value already validated in production under real player load. If you want to raise it, that needs actual testing against a live server with other addons generating net traffic at the same time, not just a local benchmark.

## Keep it simple

- Don't build an abstraction, config option, or generic system for a problem that has exactly one real use case today. Three similar lines beat a premature helper.
- Don't add error handling for situations that can't happen given how the code is actually called. Validate at real boundaries (net input, user-supplied payloads), not everywhere defensively.

## Functions

- One function, one job. If a function's name is a verb phrase (`Send`, `Encode`, `SplitIntoChunks`), it should only do what that phrase says.
- If a function is doing more than one distinct thing, split it.
- Name things for what they do, not how they're currently implemented.

## Comments

- Minimal. Default to none.
- The one exception is a hidden constraint or a WHY the code itself can't express.
- Never comment WHAT the code does. If a comment is just restating the next line, delete it.
- No decorative separators or banner-style dividers.
- No em-dashes. Use a plain hyphen or restructure the sentence.

## Bug fixes vs. features

- A bug fix changes exactly what's needed to fix the bug, in the files where the bug lives. Nothing else.
- If you notice an unrelated improvement while fixing something, don't fold it into the same change. Fix the bug first, ship that, then do the improvement as its own separate change.
