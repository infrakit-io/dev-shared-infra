# infrakit-dev-shared

Shared local-development infrastructure for laptop-based dev environments.
Provides a **Cloudflare Tunnel + Traefik** combo so multiple Dockerized apps
can be exposed simultaneously on capability-based URLs
(`<random>.dev.example.com`) without per-app tunnel setup.

## Purpose

One always-on Cloudflare Tunnel with wildcard ingress
(`*.dev.<your-domain>` -> `http://traefik:80`) fronts a local Traefik
reverse proxy. Each dev app generates a random hostname (capability-based
access), attaches Traefik labels in its own `docker-compose.yml`, and joins
the shared `dev-shared` docker network — no per-app tunnel token, no per-app
DNS edit.

Benefits over per-app `cloudflared` sidecars:
- One tunnel for N apps (no per-app token rotation).
- Random URL per app instance = capability-based access (defense in depth
  alongside Cloudflare Access policies).
- Traefik dashboard shows every routed app at a glance.
- Tunnel stays up across `docker compose down` of individual app stacks.

## Architecture

```
   Browser
      │
      ▼
  Cloudflare Edge (TLS, CDN, Access policies)
      │
      ▼
  Cloudflare Tunnel  (wildcard *.dev.example.com)
      │
      ▼
  cloudflared (local container)
      │
      ▼
  Traefik :80  (routes by Host header)
      │
      ├─► app-1  (Host=abc123.dev.example.com)
      ├─► app-2  (Host=def456.dev.example.com)
      └─► app-N  (Host=...)

  All app containers + Traefik + cloudflared share the
  docker network `dev-shared`.
```

## Prerequisites

- Docker (Desktop or Engine) with the `compose` plugin.
- [`go-task`](https://taskfile.dev) (the `task` CLI).
- A Cloudflare account with a registered domain and Zero Trust enabled.
- A Cloudflare Tunnel with a wildcard ingress rule
  (`*.dev.<your-domain>` -> `http://traefik:80`) and a connector token.
  Create one via **Cloudflare Zero Trust Dashboard -> Networks -> Tunnels**.

## Setup

```bash
cp .env.example .env
# Edit .env: paste your Cloudflare tunnel token into CF_TUNNEL_TOKEN
task up
```

Verify:
- `task status` -> traefik + cloudflared `running`, network has containers.
- `docker compose logs cloudflared` -> `Registered tunnel connection`.
- Open <http://localhost:8090/dashboard/> -> Traefik dashboard.

## Adding an app

In the consumer app's `docker-compose.yml`:

```yaml
services:
  api-dev:
    # ... your service config ...
    labels:
      - "traefik.enable=true"
      - "traefik.docker.network=dev-shared"
      - "traefik.http.routers.myapp-dev.rule=Host(`${TUNNEL_HOSTNAME}`)"
      - "traefik.http.services.myapp-dev.loadbalancer.server.port=8080"
    networks:
      - backend
      - dev-shared

networks:
  backend: {}
  dev-shared:
    external: true
    name: dev-shared
```

Then set `TUNNEL_HOSTNAME` in the app's `.env` to a random subdomain of the
wildcard zone (e.g. `8f3a2c1d.dev.example.com`) and `docker compose up -d`
the app. Traefik will pick up the new route automatically.

A capability-based hostname can be generated with something like:

```bash
echo "TUNNEL_HOSTNAME=$(openssl rand -hex 4).dev.example.com" >> .env
```

## Cleanup

| Command         | Effect                                                                          |
|-----------------|---------------------------------------------------------------------------------|
| `task down`     | Stops shared infra. Network `dev-shared` is **preserved** so other apps survive. |
| `task destroy`  | Stops shared infra **and removes** the `dev-shared` network. Disconnect apps first. |

## Tasks reference

```bash
task           # list available tasks
task up        # start shared infra (idempotent)
task down      # stop shared infra, keep network
task destroy   # full cleanup, removes network
task logs      # tail logs from all services
task status    # compose ps + network inspect summary
```

## License

MIT — see [LICENSE](./LICENSE).

## Author

Maintained by [Bibi40k](https://github.com/Bibi40k) / `infrakit-io`.
