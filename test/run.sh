#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
"${LUA:-lua}" test/smoke/security.lua
"${LUA:-lua}" test/smoke/apply_skin_bounds.lua
"${LUA:-lua}" test/smoke/login_reconcile.lua
"${LUA:-lua}" test/smoke/login_hair_colour.lua
"${LUA:-lua}" test/smoke/camera_zoom.lua
"${LUA:-lua}" test/smoke/shop_zones.lua
"${LUA:-lua}" test/smoke/session_open.lua
"${LUA:-lua}" test/smoke/head_overlays.lua
"${LUA:-lua}" test/smoke/camera_category.lua
"${LUA:-lua}" test/smoke/camera_bones.lua
"${LUA:-lua}" test/smoke/shop_interaction.lua
"${LUA:-lua}" test/smoke/radar_hide.lua
"${LUA:-lua}" test/smoke/rotate_end.lua
"${LUA:-lua}" test/smoke/rotate_lock.lua
"${LUA:-lua}" test/smoke/rotate_control.lua
"${LUA:-lua}" test/smoke/tattoo_undress.lua
"${LUA:-lua}" test/smoke/tattoo_peds.lua
"${LUA:-lua}" test/smoke/tattoo_stacking.lua
"${LUA:-lua}" test/smoke/barber_top.lua
"${LUA:-lua}" test/smoke/quicktoggle.lua
"${LUA:-lua}" test/smoke/stock_compat.lua
