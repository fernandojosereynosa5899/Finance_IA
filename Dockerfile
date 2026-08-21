FROM ubuntu:22.04

# Configurar zona horaria y evitar interacciones de apt
ENV DEBIAN_FRONTEND=noninteractive

# Instalar dependencias esenciales: Java 17, Python 3, Curl y Nginx
RUN apt-get update && apt-get install -y \
    openjdk-17-jdk \
    python3 python3-pip python3-venv \
    curl nginx \
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g pnpm \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 1. Configurar Entorno Data Science (Python)
COPY DataScient/ /app/DataScient/
RUN cd /app/DataScient && \
    python3 -m venv venv && \
    ./venv/bin/pip install --upgrade pip && \
    ./venv/bin/pip install -r requirements.txt

# 2. Configurar Backend (Java Spring Boot)
COPY Backend/financeia-backend/ /app/Backend/
RUN cd /app/Backend && \
    chmod +x ./mvnw && \
    ./mvnw clean package -DskipTests

# 3. Configurar Frontend (Astro Node)
COPY Frontend/ /app/Frontend/
RUN cd /app/Frontend && \
    pnpm install && \
    PUBLIC_API_URL=" " pnpm build

# 4. Configurar Nginx como Proxy Inverso
RUN echo 'server { \' > /etc/nginx/sites-available/default && \
    echo '    listen 8080 default_server; \' >> /etc/nginx/sites-available/default && \
    echo '    location /api/ { \' >> /etc/nginx/sites-available/default && \
    echo '        proxy_pass http://127.0.0.1:8081; \' >> /etc/nginx/sites-available/default && \
    echo '        proxy_set_header Host $host; \' >> /etc/nginx/sites-available/default && \
    echo '        proxy_set_header X-Real-IP $remote_addr; \' >> /etc/nginx/sites-available/default && \
    echo '    } \' >> /etc/nginx/sites-available/default && \
    echo '    location / { \' >> /etc/nginx/sites-available/default && \
    echo '        proxy_pass http://127.0.0.1:4321; \' >> /etc/nginx/sites-available/default && \
    echo '        proxy_set_header Host $host; \' >> /etc/nginx/sites-available/default && \
    echo '        proxy_set_header X-Real-IP $remote_addr; \' >> /etc/nginx/sites-available/default && \
    echo '    } \' >> /etc/nginx/sites-available/default && \
    echo '}' >> /etc/nginx/sites-available/default

# 5. Script de inicializacion
RUN echo '#!/bin/bash' > /app/start.sh && \
    echo 'sed -i "s/listen 8080 default_server;/listen ${PORT:-10000} default_server;/g" /etc/nginx/sites-available/default' >> /app/start.sh && \
    echo 'java -Dserver.port=8081 -jar /app/Backend/target/financeia-backend-0.0.1-SNAPSHOT.jar &' >> /app/start.sh && \
    echo 'cd /app/Frontend' >> /app/start.sh && \
    echo 'HOST=127.0.0.1 PORT=4321 INTERNAL_API_URL="http://127.0.0.1:8081" node ./dist/server/entry.mjs &' >> /app/start.sh && \
    echo 'nginx -g "daemon off;"' >> /app/start.sh && \
    chmod +x /app/start.sh

ENV PYTHON_COMMAND=/app/DataScient/venv/bin/python
ENV DATA_SCIENCE_SCRIPT=/app/DataScient/src/predict.py

EXPOSE 10000

CMD ["/app/start.sh"]