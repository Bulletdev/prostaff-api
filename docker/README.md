# Docker Configuration

This directory contains Docker Compose configurations for different environments.

## Files

- `docker-compose.yml` - Local development setup
- `docker-compose.production.yml` - Production setup (used with Coolify)
- `docker-compose.staging.yml` - Staging environment

## Usage

### Local Development

```bash
# Start all services
docker compose -f docker/docker-compose.yml up -d

# View logs
docker compose -f docker/docker-compose.yml logs -f

# Stop services
docker compose -f docker/docker-compose.yml down
```

### Production (via Coolify)

Production deployment is handled by Coolify. It uses:
- `Dockerfile.production` (in project root - required by Coolify)
- `docker/docker-compose.production.yml` (for manual operations)

Coolify automatically detects `Dockerfile.production` in the root directory.

## Services

### Local (`docker-compose.yml`)
- **api** - Rails API server (port 3333)
- **redis** - Cache and background jobs (port 6380)
- **meilisearch** - Search engine (port 7700)
- **sidekiq** - Background job processor

### Production (`docker-compose.production.yml`)
Same services as local, but configured for production with:
- Optimized resource limits
- Production-grade logging
- Health checks
- Network isolation via Coolify network

## Important Notes

1. **Dockerfiles stay in project root** - Coolify requires this
2. **docker-compose files are in docker/** - Keeps root clean
3. **Local uses port 6380 for Redis** - Avoids conflicts with system Redis
4. **Production uses Traefik** (via Coolify) for reverse proxy and SSL

## Troubleshooting

### Cannot connect to services

```bash
# Check if services are running
docker compose -f docker/docker-compose.yml ps

# Check logs
docker compose -f docker/docker-compose.yml logs api
```

### Port conflicts

If you get port conflicts (e.g., Redis 6380), check for other services:

```bash
lsof -i :6380
```

### Coolify deployment issues

Coolify expects `Dockerfile.production` in the **project root**. Do not move it.

If build fails, check Coolify logs in the web interface.
