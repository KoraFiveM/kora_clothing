#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
"${LUA:-lua}" test/smoke/security.lua
"${LUA:-lua}" test/smoke/apply_skin_bounds.lua
"${LUA:-lua}" test/smoke/login_reconcile.lua
