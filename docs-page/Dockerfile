# nginx:unprivileged runs as non-root (UID 101) on port 8080 — no permission hacks needed
FROM nginxinc/nginx-unprivileged:1.25-alpine

COPY index.html /usr/share/nginx/html/index.html
COPY logo.png   /usr/share/nginx/html/logo.png
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Explicit USER declaration — nginx-unprivileged already runs as UID 101 (non-root).
# Declared here so security scanners (SonarQube, Trivy) recognise the intent.
USER 101

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost:8080/health || exit 1
