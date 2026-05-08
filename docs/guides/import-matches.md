# Importing matches from Riot API

This guide covers the full flow from registering a player with their Riot credentials
to importing their match history into ProStaff.

---

## Prerequisites

- An authenticated user token with at least `coach` role.
- A valid Riot API key configured on the server (`RIOT_API_KEY` environment variable).
- The player's Riot ID in the format `GameName#TAG` (e.g., `Faker#KR1`).

---

## 1. Create a player

Register the player in your organization's roster with their summoner name and region.

```
POST /api/v1/players
```

Request body:

```json
{
  "player": {
    "summoner_name": "Faker#KR1",
    "role": "mid",
    "region": "kr",
    "status": "active"
  }
}
```

Valid roles: `top`, `jungle`, `mid`, `adc`, `support`

Valid regions: `br1`, `la1`, `la2`, `na1`, `euw1`, `euw2`, `kr`, `jp1`, `tr1`, `ru`, `oc1`

Successful response (201):

```json
{
  "message": "Player created successfully",
  "data": {
    "player": {
      "id": "p1q2r3s4-...",
      "summoner_name": "Faker#KR1",
      "role": "mid",
      "region": "kr",
      "status": "active",
      "sync_status": null,
      "riot_puuid": null
    }
  }
}
```

At this point the player exists in the database but has no Riot data. The `riot_puuid`
field is `null` until the first sync.

Alternatively, use the import endpoint to create and sync in one step:

```
POST /api/v1/players/import
```

Request body:

```json
{
  "summoner_name": "Faker#KR1",
  "role": "mid",
  "region": "kr"
}
```

This calls the Riot API synchronously and creates the player with `riot_puuid` already
populated. Use this path when you want the Riot data available immediately.

---

## 2. Sync player data from Riot API

Syncing fetches current ranked stats, champion pool, and profile data from the
Riot Gateway service.

```
POST /api/v1/players/:id/sync_from_riot
```

Optional query parameter:

| Parameter | Type   | Default                   | Description              |
|-----------|--------|---------------------------|--------------------------|
| region    | string | player's stored region    | Override the sync region |

Example:

```bash
curl -X POST https://api.prostaff.gg/api/v1/players/p1q2r3s4-.../sync_from_riot \
  -H "Authorization: Bearer <access_token>" \
  -H "Content-Type: application/json"
```

This call is **synchronous** — the response is returned once the Riot API call
completes. Typical latency is 1–3 seconds depending on the Riot API region.

Successful response (200):

```json
{
  "data": {
    "player": {
      "id": "p1q2r3s4-...",
      "summoner_name": "Faker#KR1",
      "riot_puuid": "some-puuid-...",
      "solo_queue_tier": "challenger",
      "solo_queue_rank": "I",
      "solo_queue_lp": 1421,
      "solo_queue_wins": 312,
      "solo_queue_losses": 241,
      "sync_status": "synced",
      "last_sync_at": "2026-04-21T14:30:00.000Z"
    },
    "message": "Player synced successfully from Riot API"
  }
}
```

If the sync fails (Riot API unavailable, invalid PUUID, rate limit), the response
is 503 with an error code:

```json
{
  "error": {
    "code": "SYNC_ERROR",
    "message": "Failed to sync with Riot API: Rate limit exceeded"
  }
}
```

---

## 3. Import match history

Once the player has a `riot_puuid`, import their recent matches:

```
POST /api/v1/matches/import
```

Request body:

| Parameter    | Type    | Required | Default | Description                                  |
|--------------|---------|----------|---------|----------------------------------------------|
| player_id    | string  | yes      | —       | Player UUID                                  |
| count        | integer | no       | 20      | Number of matches to import (max 100)        |
| force_update | boolean | no       | false   | Re-import matches that already exist         |

Example:

```json
{
  "player_id": "p1q2r3s4-...",
  "count": 20
}
```

This endpoint **enqueues a background job** via Sidekiq and returns immediately.
The import runs asynchronously.

Successful response (200):

```json
{
  "message": "Matches import started successfully",
  "data": {
    "player_id": "p1q2r3s4-...",
    "queued": true
  }
}
```

If the player does not yet have a `riot_puuid` (sync was never run), the response
is 400:

```json
{
  "error": {
    "code": "MISSING_PUUID",
    "message": "Player does not have a Riot PUUID. Please sync player from Riot first."
  }
}
```

---

## 4. Checking import status

Poll `GET /api/v1/players/:id` and inspect the `sync_status` field:

| Value      | Meaning                                             |
|------------|-----------------------------------------------------|
| `null`     | Player was never synced                             |
| `syncing`  | Sync or import job is currently running             |
| `synced`   | Last sync completed successfully                    |
| `error`    | Last sync failed — check `last_sync_at` for timing |

Example polling check:

```bash
curl https://api.prostaff.gg/api/v1/players/p1q2r3s4-... \
  -H "Authorization: Bearer <access_token>"
```

Response excerpt:

```json
{
  "data": {
    "player": {
      "sync_status": "synced",
      "last_sync_at": "2026-04-21T14:35:12.000Z"
    }
  }
}
```

There is no webhook or push notification for job completion. Poll at a reasonable
interval (every 5–10 seconds) until `sync_status` is no longer `syncing`.

---

## 5. Accessing match stats

### List matches for a player

```
GET /api/v1/players/:id/matches
```

Optional parameters:

| Parameter  | Type   | Description                     |
|------------|--------|---------------------------------|
| start_date | string | ISO 8601 date filter (start)    |
| end_date   | string | ISO 8601 date filter (end)      |
| page       | int    | Page number (default 1)         |
| per_page   | int    | Results per page (default 20)   |

### Get full stats for a specific match

```
GET /api/v1/matches/:id/stats
```

Response includes:

- `match` — match metadata (duration, result, patch, opponent)
- `team_stats` — aggregated kills, deaths, assists, gold, damage, CS, vision score
- `player_stats` — per-player breakdown with champion played, KDA, damage share
- `comparison` — total gold, damage, vision score, average KDA

---

## 6. Rate limits and expected latency

The Riot API enforces rate limits at the API key level. ProStaff uses a dedicated
riot-gateway service that manages requests internally, but the underlying limits
still apply:

- Per-method rate limits vary by endpoint (e.g., 100 requests / 2 minutes for
  account data).
- When the Riot API returns 429, the sync or import job will fail with
  `SYNC_ERROR`. Wait a few minutes before retrying.
- Bulk sync (`POST /api/v1/players/bulk_sync`) queues one job per player.
  For large rosters (10+ players) expect the full sync to take several minutes.

Typical single-player sync latency: 1–3 seconds (Riot API + gateway overhead).

---

## See also

- [Quick start](quickstart.md) — abbreviated walkthrough of this flow
- [Authentication](authentication.md) — obtaining the coach-role token required here
- [Error codes](error-codes.md) — 503 SYNC_ERROR and 400 MISSING_PUUID details
