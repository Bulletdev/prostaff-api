@echo off
cd /d "%~dp0"
echo [INFO] Restarting API and Sidekiq containers (reloading env vars)...
docker compose -f "docker\docker-compose.yml" up -d --force-recreate api sidekiq

echo [INFO] Waiting for services to be ready...
timeout /t 3 /nobreak >nul

echo [INFO] Recent logs (api):
docker logs prostaff-api --tail 10

echo [INFO] Recent logs (sidekiq):
docker logs docker-sidekiq-1 --tail 10

pause
