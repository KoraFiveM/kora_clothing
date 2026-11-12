# kora_clothing agent guide

kora_clothing is the Kora FiveM clothing, appearance, barber, tattoo and outfit wardrobe resource, using a private fitting-room routing bucket and a React NUI. It provides `qb-clothing` for compatibility. Layout: `config.lua` (shared config), `shared/components.lua` (component and prop catalogue, skin sanitising helpers), `server/` (schema, persistence bootstrap, sessions, pricing, compatibility callbacks), `client/` (session and NUI owner, camera, rotation, quick toggles), `web/` (NUI source, built into `web/build/`), `locales/`, `test/` (Lua smoke tests) and `tests/` (kora_qa features).

## Documentation

User-facing documentation lives in `docs/` (Markdown, published via the Kora Docusaurus site, kora_docs_next). Read `docs/index.md` first for an overview of features, configuration, commands, exports, events and database usage.

Docs layout: `docs/index.md` (overview, requirements and the documentation map, update it when you add a page), `docs/installation.md`, `docs/how-to-use.md` (flows: shops, tattoo studio, creation, wardrobe, quick toggles), `docs/commands.md` (commands, keybinds, menu inputs), `docs/api/` (`exports-client.md`, `exports-server.md`, `legacy-protocol.md` for events, callbacks and the qb-clothing protocol, `configuration.md` for every `config.lua` key), plus topic pages `docs/features/*`, `docs/database.md`, `docs/items.md`, `docs/compatibility.md` and `docs/troubleshooting.md`. Change the page that owns the topic instead of adding a duplicate.

When you add, change, or remove a feature, config option, command, export, event, item, permission, or database table/column, update the matching page in `docs/` in the same change. Keep docs accurate to the code; do not document behaviour that does not exist.

Docs rules: plain Markdown with `title`/`sidebar_position` front matter (no `id`/`slug`), relative links only between docs pages, assets inside `docs/`, fenced code blocks with a language, and no raw `<`, `>`, `{`, `}` outside code (pages are parsed as MDX). The release version comes from `fxmanifest.lua`'s `version` field.
