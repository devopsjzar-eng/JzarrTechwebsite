# JzarrTech

Single repository containing the JzarrTech frontend and backend.

## Projects

- `jzarrtech` - React frontend
- `jzarrtechserver` - production mail-only Express contact API

## Local commands

```bash
npm run client
npm run server
npm run build
```

## Backend configuration

The backend intentionally has no database or admin dashboard. It exposes
`POST /api/contact` and `GET /api/health`.

Create its environment configuration from `jzarrtechserver/.env.example`.
Production secrets belong only in the server-side `.env` and must not be
committed.

## Production deployment

Production is deployed from `main` at `/var/www/JzarrTechwebsite`. The deploy
script updates the repository with a fast-forward-only merge, installs locked
dependencies, runs backend tests, builds the frontend, reloads only
`jzarrtechserver`, and checks the API locally and through Nginx. It does not
modify or reload Nginx.

Run it from a local terminal:

```bash
ssh -t deploy@64.225.49.97 \
  'cd /var/www/JzarrTechwebsite && bash scripts/deploy-production.sh'
```

The production `jzarrtechserver/.env` remains on the server and is ignored by
Git.
