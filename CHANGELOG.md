# Changelog

All notable changes to this project are recorded here, newest first. The project was
created and first published on 4 November 2026; the v1.0.0 entry below is the full
record of that first day.

---

## 2026-11-23

Image: `ghcr.io/aoio-design/webtop-ubuntu-xfce-hermes-desktop:2026-11-23` (= `latest`)
Digest: `sha256:e7225990afe96ec1a70d78518103739036fe7080ce355fe5c1216ffd8d7b5803`
Platform: `linux/amd64` · Licence: GPL-3.0

### Changed

- **Base** moved to `lscr.io/linuxserver/webtop:ubuntu-xfce@sha256:25c0d9cae36f…`
  (LinuxServer `d5ef6218-ls11`, built 17 November 2026) — upstream's own package
  refresh on Ubuntu 26.04.1.
- **cloudflared** 2026.10.1 → **2026.11.1**. Both declaring files move together:
  the `Dockerfile`'s `ARG CLOUDFLARED_VERSION` and `build.sh`'s environment default,
  because `build.sh` passes `--build-arg` from its own value. The baked copy is only
  the seed — `19-cloudflared-update` plus the machine schedule keep the connector
  current afterwards.
- Selkies stays at 2.2.1 (the newest PyPI release). No boot hook, seed file or
  compose change: a pull and a recreate is the whole update.

### Verified

| Check | Result |
|---|---|
| Desktop answers over HTTPS with 401 (auth gate up) | PASS |
| Selkies browser client present and served (`assets/index-BD8uW1M7.js`) | PASS |
| Seeded crontab, cloudflared on the volume, cloudflared updater on the schedule, security updater + schedule | 4 PASS |
| Hermes absent, no studio tree (this image installs the agent at first boot) | PASS |
| Baked build info and image labels | base `25c0d9ca…` · selkies 2.2.1 · cloudflared 2026.11.1 |
| `cloudflared --version` inside the image | `2026.11.1` |
| Anonymous `docker pull` (no credentials) | 200, digest `e7225990…` |

### Updating

`docker compose pull && docker compose up -d`. Everything you added lives on the
mounted volumes and survives; do not use `down -v`.

---

## 2026-11-10

Image: `ghcr.io/aoio-design/webtop-ubuntu-xfce-hermes-desktop:2026-11-10`
Digest: `sha256:102299402ed7167a682031ef6544a0d436a5a20f4b8913c5d9d07390d0fffdb1`
Platform: `linux/amd64` · Licence: GPL-3.0

### Fixed

- **The daily security patch run patched nothing.** The machine schedule runs it as
  the desktop user (`abc`), while `apt` and `/etc/apt` need root, so every run printed
  `could not write … (are we root?)` and exited — silently on any machine with no chat
  notification configured. `bin/aoio-security-update` now re-executes itself under
  `sudo -n` when it is not root (this base grants `abc` passwordless sudo) and fails
  loudly if it cannot escalate, instead of appearing to have run.

### Changed

- **Base** moved to `lscr.io/linuxserver/webtop:ubuntu-xfce@sha256:14fa1ceb750d…`
  (LinuxServer `76362218-ls10`) — upstream's Ubuntu 26.04.1 package refresh.
- Selkies 2.2.1 and cloudflared 2026.10.1, unchanged from the 4 November rebuild.

### Verified

- Image labels read back from the published artifact: `io.aoio.base.image`
  `14fa1ceb…`, `io.aoio.selkies.version` 2.2.1, `io.aoio.cloudflared.version`
  2026.10.1.
- Anonymous `docker pull` (no credentials): 200, digest `10229940…`.

---

## v1.0.0 — 2026-11-04

Image: `ghcr.io/aoio-design/webtop-ubuntu-xfce-hermes-desktop:2026-11-04`
Digest: `sha256:ff6d97b513de687d1a0b070d4eecd30b49aac3fcbab5d981d0b6f9b504561a72`
Platform: `linux/amd64` · Licence: GPL-3.0

### Added

**Image**
- `Dockerfile` on `lscr.io/linuxserver/webtop:ubuntu-xfce`. The base is a floating
  tag by default, so a plain `docker build` takes the newest upstream base;
  `build.sh` resolves the tag to its current digest and pins it for a published,
  reproducible image.
- Selkies upgraded over the base image's older client (pinned to 2.2.0;
  `SELKIES_VERSION=latest` takes the newest PyPI release).
- cloudflared baked and version-pinned (2026.10.1).
- Build-time assertions covering both presence (every hook and helper, the
  streamer version, the upgraded browser client, chromium) and absence (no studio
  payload, no seeded agent home).

**Boot hooks** (13, run in filename order by the base image's init)
- `05-packages`, `07-security-update`, `10-seed-config`, `12-cloudflared-volume`,
  `15-timezone`, `17-security-update-cron`, `18-update-watch`,
  `19-cloudflared-update`, `20-crontab-install`, `25-cloudflared-tunnel`,
  `40-hermes-glue`, `90-firstboot` — carried over from the earlier cloud-computer
  recipe and adapted to this image's single `/config` volume.
- `08-desktop-password` — new. If `PASSWORD` is a placeholder, generate a strong
  one, store it at `/config/.desktop-password` (mode 600, owned by the desktop
  user) and put it in front of the login. A real password is never touched.

**First-boot agent install**
- `bin/aoio-firstboot-install` + `custom-cont-init.d/90-firstboot`: Nous Research's
  official installer, run once in the background with `--include-desktop`, into
  `/config/hermes-agent` with `HERMES_HOME=/config/.hermes` — so the agent is the
  current release on the day of deployment and survives every recreate.
- `desktop.electron_flags = ["--no-sandbox"]` is written after install (required:
  Electron's sandbox cannot initialise inside a container). The launcher also sets
  `ELECTRON_DISABLE_SANDBOX=1`, so either alone is sufficient.

**Payload and launchers**
- Seeded onto the volume only when absent: the machine crontab, the notification
  helper, the Chromium and Hermes desktop entries, the quiet autostart entry, and
  `start-hermes-desktop.sh` (which carries the four environment variables the app
  needs to resolve its CLI, its checkout and its display).

**Packaging**
- `docker-compose.yml` (published image — reproducible) and
  `docker-compose.build.yml` (every upstream piece resolved at deploy time).
- `build.sh`, `README.md`, `LICENSE` (GPL-3.0), `.gitignore`, GitHub Release
  `v1.0.0`.

### Fixed

- **`08-desktop-password` did nothing on its first implementation.** Measured on
  this base: `init-nginx` is a oneshot that depends only on `init-selkies`, so it
  runs **before** `/custom-cont-init.d` hooks. Writing `PASSWORD` into
  `/run/s6/container_environment` was therefore too late — the nginx htpasswd had
  already been generated from the placeholder, and `changeme` still logged in
  (HTTP 200) while the generated password was rejected (401). The hook now also
  regenerates `/etc/nginx/.htpasswd` itself, with the same tool and format
  (`openssl passwd -apr1`). Safe because the nginx *service* starts from
  `init-services`, downstream of the hooks. It keeps writing the environment
  variable too, so the hook stays correct if a future base reverses that order.

### Verified

Evidence from the test container used during this release:

| Check | Result |
|---|---|
| Login with no credentials | 401 |
| Login with `changeme` | 401 (rejected) |
| Login with generated password (HTTP and HTTPS) | 200 |
| Password across a container restart | unchanged; login 200; placeholder still 401 |
| Re-seed on restart | 6 files kept, none overwritten |
| Streamer | `selkies 2.2.0` |
| Studio payload / seeded agent home | absent, as intended |
| Machine crontab | 3 lines installed for `abc` |
| Real agent install (not a dry run) | Hermes Agent v0.22.7, `b200f5bc60`, 2.5 GB, **274 s** |
| Desktop app launch | Electron process running with `--no-sandbox` |
| `desktop.electron_flags` | `["--no-sandbox"]` written to `/config/.hermes/config.yaml` |
| Anonymous `docker pull` (no credentials) | 200, digest `ff6d97b5…` |

### Known limitations

- `linux/amd64` only — no arm64 build.
- One-click deployment through a hosting provider's catalogue was **not** tested
  on the provider's own platform; only the repository layout they consume
  (compose at the root, public repo, open-source licence) was verified.
- The agent's gateway is a user step: after first-run setup, `hermes gateway
  install`. Nothing installs it automatically, because it needs a configured
  profile first.
- Changing the GHCR package's visibility cannot be done with a classic personal
  access token through the API (every documented endpoint returns 404); it is a
  package-settings action in the web UI.
