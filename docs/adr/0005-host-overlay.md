# 0005 — The host overlay is the only deployment layer

Status: accepted

`docker-compose.local.yml` is gitignored. It carries host binds, the agent tree,
GPU devices and host-specific limits. `compose/host.example.yml` and
`examples/compose/local.yml` are placeholders; `make` accepts
`LOCAL_COMPOSE=docker-compose.local.yml`. The generic core stays host-free.
