# Stage 1: install all dependencies (incl. dev) and run tests
FROM node:24-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY server.js .

# Stage 2: production image with only runtime deps, running as non-root
FROM node:24-alpine
ENV NODE_ENV=production
WORKDIR /app
COPY --from=build /app/package*.json ./
RUN npm install --omit=dev && npm cache clean --force
COPY --from=build /app/server.js .
USER node
EXPOSE 3000
CMD ["node", "server.js"]
