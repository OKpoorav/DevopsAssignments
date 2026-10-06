FROM node:22-alpine
ARG APP_VERSION=1
ENV APP_VERSION=${APP_VERSION}
WORKDIR /app
COPY server.js .
EXPOSE 8080
CMD ["node", "server.js"]
