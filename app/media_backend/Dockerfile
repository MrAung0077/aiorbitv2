FROM node:22-bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ffmpeg ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY package.json ./
COPY src ./src
RUN mkdir /data && chown node:node /data
USER node
ENV MEDIA_DATA_DIR=/data PORT=8080
VOLUME /data
EXPOSE 8080
CMD ["node", "src/server.js"]
