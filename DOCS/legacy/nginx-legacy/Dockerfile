FROM nginx:alpine

# Install curl for healthchecks
RUN apk add --no-cache curl

# Create cache directory with proper permissions
RUN mkdir -p /var/cache/nginx/riot_api && \
    chown -R nginx:nginx /var/cache/nginx && \
    chmod -R 755 /var/cache/nginx

# Create log directory
RUN mkdir -p /var/log/nginx && \
    chown -R nginx:nginx /var/log/nginx

# Copy nginx configuration files
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY nginx/app.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

# Switch to nginx user for security
USER nginx

# The nginx -t test will run at container startup when DNS is available
CMD ["nginx", "-g", "daemon off;"]
