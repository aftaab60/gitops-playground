# Flutter web must be built before running docker build:
#   cd frontend && flutter build web --release
# Then from the project root:
#   docker build -t gitops-tracker-frontend:dev ./frontend
FROM nginx:alpine
COPY build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
