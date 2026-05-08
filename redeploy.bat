@echo off
cd /d "%~dp0"
echo [INFO] Bringing down all services...
docker compose -f "docker\docker-compose.yml" down

echo [INFO] Starting all services...
docker compose -f "docker\docker-compose.yml" up -d

echo [INFO] Waiting for services to be ready...
timeout /t 5 /nobreak >nul

echo [INFO] Service status:
docker compose -f "docker\docker-compose.yml" ps

echo [INFO] Recent API logs:
docker compose -f "docker\docker-compose.yml" logs api --tail 20

pause
