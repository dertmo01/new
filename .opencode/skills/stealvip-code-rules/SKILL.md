---
name: stealvip-code-rules
description: Use ONLY when editing the stealvip2 / YOKUDO HUB Roblox Luau repository (Loader.lua, Features/*.lua, Tabs/*.lua). Enforces inspect-first, reuse existing functions, verified-API/research-only, and minimal safe changes before writing any Lua.
---

# stealvip2 / YOKUDO HUB — Code Rules

Apply to every task in this repository (Roblox Luau exploit hub: `Loader.lua`,
`Features/*.lua`, `Tabs/*.lua`).

## Repository map (inspect before assuming)
- Entry point: `Loader.lua`. It sets `BASE_URL` and fetches every file with
  `game:HttpGet(BASE_URL .. path)` through `GetScript()`; results cached in
  `_G.YOKUDO_Cache`. Do not hardcode per-file URLs.
- Load order: `Config.lua` -> `UI.lua` -> `Components.lua` -> `Features/ConfigSystem.lua`
  -> other `Features/*` -> `Tabs/*` -> `ConfigSystem.Load()` at the end.
- Features export modules on `_G.YOKUDO_<Name>` (e.g. `_G.YOKUDO_AFKSystem`,
  `_G.YOKUDO_FarmingManager`, `_G.YOKUDO_AutoTreadmill`, `_G.YOKUDO_ConfigSystem`).
- Tabs register via `_G.YOKUDO_TabsManager` and build UI from `Components.lua`;
  each tab owns its local state and a `_G.YOKUDO_Refresh<Name>UI` hook.
- Persistence uses the push registry: `ConfigSystem.Register(key, {Get, Set, Deferred})`.

## Priority (highest first)
1. EXISTING CODE
2. EXISTING FUNCTIONS
3. VERIFIED DOCUMENTATION / API
4. VERIFIED ONLINE EXAMPLE
5. NEW IMPLEMENTATION (last resort)

## Core rules
1. ALWAYS inspect the existing codebase before implementing anything.
2. Search the entire repository for existing functions, modules, variables,
   events, handlers, utilities, and related logic before creating new code.
3. Prefer reusing existing functions and extending existing implementations
   instead of creating duplicates.
4. Do not rewrite working code unnecessarily.
5. Make the smallest safe change needed to fix a problem.
6. Preserve existing working features.
7. Never invent or guess APIs, RemoteEvents, RemoteFunctions, event names,
   object paths, services, properties, game mechanics, callbacks, arguments,
   or return values.
8. If a requested feature needs an API or game function not already present,
   verify it actually exists from a reliable source before implementing.
9. If an API/function cannot be verified, say so instead of guessing or
   fabricating an implementation.
10. Do not use random code from an unverified source as proof an API exists.
11. When debugging, inspect the relevant existing code and trace the actual
    cause before modifying anything.
12. Do not randomly rewrite multiple files to solve one problem.
13. Before major changes, explain what existing code will be reused, which
    files change, and why.
14. After changes, check syntax, references, and affected functionality.
15. Never claim something is fixed or working unless there is evidence.
16. Be honest about what was inspected, changed, verified, and not tested.

## Resource and web research rules
17. You may search the web for Lua resources, documentation, examples, scripts,
    APIs, libraries, and implementations when the existing repository does not
    contain what is needed.
18. You may search sources such as GitHub, GitHub Gist, official documentation,
    Lua documentation, Roblox/API documentation when applicable, developer
    forums, and other publicly available programming resources.
19. Trust the user as the source of the requested goal and requirements, but do
    NOT automatically trust code found online.
20. Treat online code as a reference until it has been verified.
21. Before using an online function, API, event, RemoteEvent, RemoteFunction,
    service, property, method, library, or object path: verify it actually
    exists; verify its correct name and usage; check compatibility with the
    current project; inspect the source/context when available; compare it with
    the existing repository implementation.
22. Prefer official documentation or primary sources when verifying an API.
23. If using code from GitHub, Gist, or another third-party source: identify
    where it came from; inspect what it actually does; adapt only the relevant
    portion; do not blindly copy the entire script; do not assume comments or
    variable names prove that an API exists.
24. If multiple online resources disagree, investigate the difference instead
    of guessing.
25. If the required API/function cannot be verified, clearly tell the user that
    it could not be verified and do not fabricate a replacement.
26. Web research must support the EXISTING CODE FIRST principle:
    EXISTING CODE -> EXISTING FUNCTIONS -> VERIFIED DOCUMENTATION/API ->
    VERIFIED ONLINE EXAMPLE -> NEW IMPLEMENTATION.
27. When an online resource solves the requested problem, explain briefly how it
    relates to the existing code before applying it.
28. Never claim that an online script is safe, compatible, functional, or
    correct unless there is evidence supporting that conclusion.

## Final priority (order of operations)
1. Understand the user's requested goal.
2. Inspect the existing repository.
3. Reuse existing code/functions whenever possible.
4. Search the web when additional information or a missing implementation is
   required.
5. Verify APIs and online code before using them.
6. Make the smallest targeted change.
7. Test/check the result.
8. Report honestly what was verified and what was not.

## Verification commands
- Syntax: `luau-analyze <file>` (installed). Syntax errors are blocking;
  non-syntax type warnings are advisory.
- Reference check: grep for the touched symbol across `Features/`, `Tabs/`, and
  `Loader.lua`.

## Reporting
Always report explicitly:
- What was inspected
- What was changed (files + lines)
- What was verified (and the command/output)
- What was NOT tested, and any unverified assumptions
