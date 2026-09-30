#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
"${LUA:-lua}" test/smoke/security.lua
"${LUA:-lua}" test/smoke/apply_skin_bounds.lua
"${LUA:-lua}" test/smoke/login_reconcile.lua
"${LUA:-lua}" test/smoke/camera_zoom.lua
"${LUA:-lua}" test/smoke/shop_zones.lua
"${LUA:-lua}" test/smoke/session_open.lua
