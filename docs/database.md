---
title: Database
sidebar_position: 7
---

kora_clothing owns two tables, declared in `server/schema.lua`. At start, `server/persistence.lua` waits for kora_sql (up to 60 s) and applies them with `Kora.sql.ensureTables`, so no SQL import is needed. Schema warnings are printed to the console. When the tables are ready, the local server event `kora_clothing:server:persistenceReady` fires.

## playerskins

The current appearance of each citizen.

| Column | Type | Notes |
| --- | --- | --- |
| `citizenid` | `varchar(50)` | Primary key |
| `model` | `varchar(64)` | `mp_m_freemode_01` or `mp_f_freemode_01` |
| `skin` | `longtext` | JSON skin (see below) |
| `updated_at` | `timestamp` | Default `CURRENT_TIMESTAMP`, updated on change |

Written with `INSERT ... ON DUPLICATE KEY UPDATE` when a session is confirmed and when an outfit item is used.

## playeroutfits

Named outfits saved from the menu.

| Column | Type | Notes |
| --- | --- | --- |
| `id` | `int unsigned` | Primary key, auto increment |
| `citizenid` | `varchar(50)` | Index `idx_playeroutfits_citizenid` |
| `outfitname` | `varchar(50)` | |
| `model` | `varchar(64)` | |
| `skin` | `longtext` | JSON skin |
| `created_at` | `timestamp` | Default `CURRENT_TIMESTAMP` |

The number of rows per citizen is limited by `Config.wardrobe.maxOutfits` when saving. All reads and deletes are filtered by the caller's own `citizenid`.

## Skin format

```json
{
  "components": { "3": { "d": 15, "t": 0 }, "11": { "d": 4, "t": 2 } },
  "props": { "0": { "d": 12, "t": 0 } },
  "tattoos": ["business_luxury", "business_luxury"],
  "hairColor": 3,
  "hairHighlight": 5,
  "head": {
    "skinTone": 4,
    "shapeFirst": -1, "shapeSecond": -1, "skinFirst": -1, "skinSecond": -1,
    "shapeMix": 0.5, "skinMix": 0.5,
    "beard": -1, "beardOpacity": 1, "beardColor": -1,
    "eyebrows": 2, "eyebrowsOpacity": 1, "eyebrowsColor": -1,
    "chestHair": -1, "chestHairOpacity": 1, "chestHairColor": -1,
    "makeup": -1, "makeupOpacity": 1, "makeupColor": -1,
    "blush": -1, "blushOpacity": 1, "blushColor": -1,
    "lipstick": -1, "lipstickOpacity": 1, "lipstickColor": -1
  }
}
```

- `components` keys are GTA component IDs 0 to 11 as strings. `props` keys are prop slots 0, 1, 2, 6 and 7. A missing prop means none.
- `d` (drawable) is clamped to -1..999 and `t` (texture) to 0..999 on the server. The client checks them again against the live ped before applying.
- `tattoos` is an ordered list of `Config.tattoos` IDs. A repeated ID is a stacked instance.
- `hairColor` and `hairHighlight` are hair palette indices (0 to 63).
- `head` is described in [Hair, head and heritage](./features/hair-and-head.md). Missing keys take their defaults, so older rows still load.

Most server read paths sanitise the stored JSON, and the client also checks every drawable and texture index against the live ped before applying it.
