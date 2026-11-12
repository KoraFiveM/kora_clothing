---
title: "Server export"
sidebar_position: 3
---


# Server export

A single server export, used by `kora_admin`'s self-service clothing/barber/tattoo/creation command to open a free session on a target player.

Namespace: `exports.kora_clothing` · Source: `server/server.lua`

## How it works

Restricted to calls originating from the `kora_admin` resource. Requests are reconciled against the target's own live session-request event, which re-checks the grant (or the target's own admin permission) before the NUI opens.

## Terms used on this page

| Term | Meaning |
| --- | --- |
| Grant | A `{ service, expiresAt }` record stored for the target player for 10 seconds, consumed exactly once by the matching `requestSession('admin', ...)` call. |

## Functions

One export.

### `exports.kora_clothing:OpenAdminSession(targetSrc, service)`

Opens a free, unrestricted appearance session (clothing + hair + tattoos, no shop/model policy) on a target player, on behalf of an already-authorized admin caller.

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `targetSrc` | number | Target player's server id. Must be online and have a resolvable citizen id. |
| `service` | string | One of `'clothing'`, `'barber'`, `'tattoo'`, `'creation'`. |

**Returns**

- **`true` on success.**
- **`false, 'only kora_admin may open a remote admin session'` when the caller is not the `kora_admin` resource.**
- **`false, 'target is not online'`.**
- **`false, 'that player already has a clothing session open'`.**
- **`false, 'invalid appearance service'`.**

**Example**

```lua
-- kora_admin, after its own permission check and target resolution:
local ok, err = exports.kora_clothing:OpenAdminSession(targetSrc, 'clothing')
if not ok then print(err) end
```

**Representative console output**

```text
Gated by `GetInvokingResource() == 'kora_admin'` — no other resource can call it. It issues a short-lived (10 second) grant consumed by the target's own session-request flow; it does not itself open the NUI on the target (that happens when their client answers `kora_clothing:client:openAdminSession`). The target's own `kora_core` admin permission is also accepted as a fallback authorization path.
```

## Additional notes from the code

#### OpenAdminSession

```lua
local ok, err = exports.kora_clothing:OpenAdminSession(targetSrc, service)
```

Opens a free admin appearance session for another player. **Only the `kora_admin` resource may call it.** For any other caller it returns `false, 'only kora_admin may open a remote admin session'`.

- `targetSrc`: server ID of an online player with a loaded character.
- `service`: `'clothing'`, `'barber'`, `'tattoo'` or `'creation'`. A barber session for a female model uses the hairdresser policy.
- Returns `true`, or `false` with one of: `'target is not online'`, `'that player already has a clothing session open'`, `'invalid appearance service'`.
- Creates a one-use grant valid for 10 seconds and triggers `kora_clothing:client:openAdminSession` on the target.



## Limits and related APIs

Server only. Returns `false` with a reason string rather than throwing on every rejection path, so callers should always check the first return value.

## Related guides

- [Client exports](./exports-client.md)
- [Legacy qb-clothing protocol](./legacy-protocol.md)
