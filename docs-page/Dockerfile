FROM nginx:1.25-alpine

# Copy Swagger UI docs page
COPY index.html /usr/share/nginx/html/index.html
COPY logo.png   /usr/share/nginx/html/logo.png

# Copy nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Grant nginx user write access to runtime directories before dropping root
RUN mkdir -p /var/cache/nginx /var/run /var/log/nginx \
 && chown -R nginx:nginx /var/cache/nginx /var/run /var/log/nginx \
 && touch /var/run/nginx.pid \
 && chown nginx:nginx /var/run/nginx.pid

USER nginx

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost/health || exit 1
