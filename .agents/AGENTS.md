# Agent Instructions and Context: shiny-agro-phaseolus

This repository contains the Shiny application for Agrobiodiversity Phaseolus (frijol) by CONABIO.

## Key Information

- **Technology Stack**: This is an R-based Shiny application (`global.R`, `ui.R`, `server.R`).
- **Deployment**: The application must be deployed and run using Docker or Podman.
- **Local Development & Running**:
  - Use `podman compose up --build -d` (or `docker compose up --build -d`) to build and run the application container.
  - The application inside the container expects paths relative to `/srv/shiny-server/`.
  - Make sure that directories containing necessary application assets (such as `extra_files` or `data`) are NOT excluded by `.dockerignore` unless they are mounted dynamically.
  - To check if the application is running, visit `http://localhost:3838` (or the port specified in `docker-compose.yml`).
  - To stop the application, use `podman compose down -v` (or `docker compose down`).
