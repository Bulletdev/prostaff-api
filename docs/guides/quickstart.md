# Quick start

This guide takes you from zero to a live roster with Riot data in five steps.
Each step includes a complete cURL example and the expected response.

Base URL: `https://api.prostaff.gg`

All endpoints are prefixed with `/api/v1/`.

---

## Step 1 — Register your organization and user

Create an organization and its owner account in a single request.

```bash
curl -X POST https://api.prostaff.gg/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "email": "owner@yourteam.gg",
      "password": "YourSecurePassword1!",
      "full_name": "Team Owner"
    },
    "organization": {
      "name": "Team Valor",
      "region": "BR"
    }
  }'
```

Expected response (201):

```json
{
  "message": "Registration successful. Your 14-day trial has started!",
  "data": {
    "user": {
      "id": "a1b2c3d4-...",
      "email": "owner@yourteam.gg",
      "full_name": "Team Owner",
      "role": "owner"
    },
    "organization": {
      "id": "e5f6g7h8-...",
      "name": "Team Valor",
      "region": "BR"
    },
    "access_token": "eyJhbGciOiJIUzI1NiJ9...",
    "refresh_token": "eyJhbGciOiJIUzI1NiJ9...",
    "expires_in": 86400,
    "token_type": "Bearer"
  }
}
```

The response includes tokens — you are already authenticated. Save both tokens.

If the organization name or email is already taken, you will receive 422 with code
`DUPLICATE_ORGANIZATION` or `DUPLICATE_EMAIL`.

---

## Step 2 — Log in and save the token

If you registered in step 1 you already have a token. For subsequent sessions:

```bash
curl -X POST https://api.prostaff.gg/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "owner@yourteam.gg",
    "password": "YourSecurePassword1!"
  }'
```

Expected response (200):

```json
{
  "message": "Login successful",
  "data": {
    "user": { ... },
    "organization": { ... },
    "access_token": "eyJhbGciOiJIUzI1NiJ9...",
    "refresh_token": "eyJhbGciOiJIUzI1NiJ9...",
    "expires_in": 86400,
    "token_type": "Bearer"
  }
}
```

Store both tokens. The access token expires in 24 hours; use the refresh token
to get a new pair without logging in again (see [Authentication](authentication.md)).

For the rest of this guide, replace `<access_token>` with your token value.

---

## Step 3 — Create a player

Add a player to your roster. The `summoner_name` should be the player's Riot ID
in `GameName#TAG` format.

```bash
curl -X POST https://api.prostaff.gg/api/v1/players \
  -H "Authorization: Bearer <access_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "player": {
      "summoner_name": "ProPlayer#BR1",
      "role": "mid",
      "region": "br1",
      "status": "active"
    }
  }'
```

Valid roles: `top`, `jungle`, `mid`, `adc`, `support`

Valid regions: `br1`, `la1`, `la2`, `na1`, `euw1`, `euw2`, `kr`, `jp1`, `tr1`, `ru`, `oc1`

Expected response (201):

```json
{
  "message": "Player created successfully",
  "data": {
    "player": {
      "id": "p1q2r3s4-...",
      "summoner_name": "ProPlayer#BR1",
      "role": "mid",
      "region": "br1",
      "status": "active",
      "sync_status": null,
      "riot_puuid": null,
      "solo_queue_tier": null,
      "solo_queue_rank": null,
      "solo_queue_lp": null
    }
  }
}
```

The player exists in the database. Riot data (`riot_puuid`, rank, champion pool)
is not populated until you sync in step 4.

Save the `player.id` — you will need it for the next steps.

---

## Step 4 — Sync with Riot API

Pull the player's current rank and profile data from Riot:

```bash
curl -X POST https://api.prostaff.gg/api/v1/players/p1q2r3s4-.../sync_from_riot \
  -H "Authorization: Bearer <access_token>" \
  -H "Content-Type: application/json"
```

This call is synchronous and typically completes in 1–3 seconds.

Expected response (200):

```json
{
  "data": {
    "player": {
      "id": "p1q2r3s4-...",
      "summoner_name": "ProPlayer#BR1",
      "riot_puuid": "some-puuid-value-...",
      "solo_queue_tier": "diamond",
      "solo_queue_rank": "II",
      "solo_queue_lp": 74,
      "solo_queue_wins": 185,
      "solo_queue_losses": 171,
      "sync_status": "synced",
      "last_sync_at": "2026-04-21T15:00:00.000Z"
    },
    "message": "Player synced successfully from Riot API"
  }
}
```

Tier values: `iron`, `bronze`, `silver`, `gold`, `platinum`, `emerald`, `diamond`,
`master`, `grandmaster`, `challenger`

If you want to also import recent match history, call the import endpoint after sync:

```bash
curl -X POST https://api.prostaff.gg/api/v1/matches/import \
  -H "Authorization: Bearer <access_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "player_id": "p1q2r3s4-...",
    "count": 20
  }'
```

This enqueues a background job. Poll `GET /api/v1/players/p1q2r3s4-...` and wait
for `sync_status` to change from `syncing` to `synced`. See
[Importing matches](import-matches.md) for details.

---

## Step 5 — List your players

Fetch the roster for your organization:

```bash
curl https://api.prostaff.gg/api/v1/players \
  -H "Authorization: Bearer <access_token>"
```

Optional query parameters:

| Parameter | Type   | Description                                  |
|-----------|--------|----------------------------------------------|
| role      | string | Filter by role (top, jungle, mid, adc, support) |
| status    | string | Filter by status (active, inactive, benched, trial) |
| search    | string | Search by summoner name or real name         |
| page      | int    | Page number (default 1)                      |
| per_page  | int    | Results per page (default 20, max 100)       |

Expected response (200):

```json
{
  "data": {
    "players": [
      {
        "id": "p1q2r3s4-...",
        "summoner_name": "ProPlayer#BR1",
        "role": "mid",
        "status": "active",
        "solo_queue_tier": "diamond",
        "solo_queue_rank": "II",
        "solo_queue_lp": 74,
        "sync_status": "synced"
      }
    ],
    "pagination": {
      "current_page": 1,
      "per_page": 20,
      "total_pages": 1,
      "total_count": 1,
      "has_next_page": false,
      "has_prev_page": false
    }
  }
}
```

---

## What happens if a request fails

- **401** — Your token expired. Run step 2 again or call `POST /api/v1/auth/refresh`
  with your stored refresh token.
- **403** — Your account role does not have permission. Player creation and sync
  require coach role or above.
- **422** — Validation error. Check the `details` field for per-field messages.
- **503** — The Riot API is unavailable. Wait a few minutes and retry.

Full error reference: [Error codes](error-codes.md).

---

## Next steps

- [Authentication](authentication.md) — token refresh, logout, player auth
- [Multi-tenancy](multi-tenancy.md) — how organization isolation works
- [Importing matches](import-matches.md) — complete match import flow with stats
- [Error codes](error-codes.md) — full error reference with rate limits
