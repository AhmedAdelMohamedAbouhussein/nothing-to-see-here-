FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

# Install Node.js 22 (latest) + required tools
RUN apt-get update && apt-get install -y curl \
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs bc lm-sensors smartmontools intel-gpu-tools iproute2 \
    && rm -rf /var/lib/apt/lists/*

# Backend
WORKDIR /App/backend
COPY backend/package*.json ./
RUN npm install
COPY backend/ ./
RUN chmod +x src/test.sh

# Frontend
WORKDIR /App/frontend
COPY frontend/package*.json ./
RUN npm install
COPY frontend/ ./

# Expose ports
EXPOSE 8000 5173

# Start backend and frontend (development)
WORKDIR /App
CMD ["sh", "-c", "cd /App/backend && npm run main & cd /App/frontend && npm run dev"]
