# Contributing

Contributions are welcome, whether that's a bug report, a feature suggestion, or a pull request.

## Using AI tools

Using AI assistants (Claude, Copilot, ChatGPT, or anything else) to help write a contribution is fine. This project's own history includes AI-assisted work. What matters is the result, not how you got there.

That said, if you submit AI-assisted code:

- You are responsible for it. Read it, understand it, and be able to explain why it works and why it's the right approach, the same as you would for code you wrote by hand.
- Don't submit output you haven't verified. If you can't explain a design decision or a line of code in your own words, it isn't ready to submit.
- Be able to justify the technical choices, not just the fact that it runs. "The AI suggested it" is not a rationale a reviewer can act on.
- Test it. The library's pure logic (encoding, chunking, the wire format, reassembly) was validated with a standalone Lua test harness, but that harness stubs `net`/`util`/`hook` and does not replace testing inside a real GMod server. Run it in-game before opening a PR, especially for anything touching the send queue, the throttle, or the wire format.

## Submitting changes

1. Open an issue first for anything non-trivial, so the approach can be discussed before you put time into it.
2. Keep pull requests focused. One change, one PR.
3. Match the existing code style (no comments explaining what the code already says, consistent naming with the surrounding file).
4. Describe what changed and why in the PR description.

## Reporting bugs

Include repro steps, what you expected, what happened instead, and relevant console output.
