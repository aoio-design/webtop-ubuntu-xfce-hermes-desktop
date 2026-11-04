# Webtop Ubuntu XFCE + Hermes Agent Desktop

A full Ubuntu Linux desktop that runs on your server and opens in a browser tab —
with a Cloudflare Tunnel connector for private remote access, and the
[Hermes Agent](https://hermes-agent.nousresearch.com) (CLI **and** desktop app)
installed for you on first boot.

No VNC client, no RDP, no VPN, nothing to install on the machine you are sitting
at.

```
docker pull ghcr.io/aoio-design/webtop-ubuntu-xfce-hermes-desktop:latest
```

---

## What you get

- **A real XFCE desktop on Ubuntu**, streamed over WebRTC at up to 60 fps with
  audio, clipboard and file transfer — in any modern browser.
- **A home folder that persists.** Settings, open projects, installed programs and
  the agent's own home all live in one mounted folder that survives updates and
  container recreates.
- **Chromium, a terminal and a file manager**, ready on the desktop.
- **The Hermes Agent**, installed from upstream's own installer on first boot, with
  its desktop app on the desktop and an icon to click. Bring your own API keys.
- **Optional private access through a Cloudflare Tunnel** — no ports on the public
  internet, and you can put Cloudflare Access in front of it.
- **Automatic Ubuntu security updates**, applied at boot and daily, so a machine
  that runs for months does not drift out of patch.
- **One-click deployment** with Docker Compose, on any Docker host (including
  Hostinger VPS Docker Manager).

## Quick start

```bash
git clone https://github.com/aoio-design/webtop-ubuntu-xfce-hermes-desktop.git
cd webtop-ubuntu-xfce-hermes-desktop
mkdir -p config shared
docker compose up -d
```

Open **https://your-server:3001** and sign in. The certificate is self-signed, so
your browser will warn you once — that is expected on a first run. Put your own
reverse proxy or Cloudflare Tunnel in front when you want a real certificate.

Then watch the agent install itself:

```bash
docker compose exec desktop tail -f /config/logs/firstboot.log
```

The desktop is usable in under a minute. The agent takes a few minutes longer
(about 1 GB of download and a desktop-app build) and then appears on the desktop,
already running at your next login.

### After the agent finishes installing

The agent is installed, not configured — it has no API keys and no profile yet.
Two short steps, once:

1. Open **Hermes Agent** on the desktop and complete its first-run setup (it asks
   for your model provider and key).
2. In a terminal on the desktop, run `hermes gateway install` so the agent's
   gateway is supervised by the container's init and comes back by itself after a
   restart or a container update.

Everything both steps create lives on the mounted volume and survives updates.

## First boot, in plain words

Two things happen at once when the container starts:

1. **The desktop comes up** — nginx, the Selkies streamer, XFCE, the tunnel
   connector if you gave it a token.
2. **The agent installs itself in the background** — Nous Research's official
   installer, run once, into `./config`. This is deliberately not baked into the
   image: baked, it would be frozen on the day the image was built. Installed at
   boot, it is the current release on the day you deploy — and it lands on your
   volume, so a container update or recreate does not throw it away.

Everything it creates is on the mounted volume, so an interrupted install simply
resumes at the next start.

## Settings you can change

| Variable | Default | What it does |
|---|---|---|
| `CUSTOM_USER` | `admin` | Your desktop login name. |
| `PASSWORD` | `changeme` | Your desktop password. A placeholder is **replaced at boot** with a generated 24-character password, written to `config/.desktop-password` — set your own and it is left alone. |
| `TITLE` | `Webtop Ubuntu XFCE` | The name shown in the browser tab. |
| `CLOUDFLARE_TUNNEL_TOKEN` | *(empty)* | Token for a remote-managed Cloudflare Tunnel. Empty means the connector does not start. |
| `SELKIES_ENABLE_SHARING` | `false` | Keep it false. Sharing links carry no authentication of their own and grant the same power as the primary user, including a terminal with passwordless sudo inside the container. |
| `PUID` / `PGID` | `10000` | Owner of the files on your volume. |

Volumes: `./config` (the desktop's home — back this up) and `./shared` (a folder
both the desktop user and any agent can read and write). Ports: `3001` (HTTPS,
self-signed) and `3000` (plain HTTP, for your own TLS-terminating proxy).

`shm_size: 2gb` is not decoration — Chromium and the desktop need more shared
memory than Docker's 64 MB default.

## How each part stays current

This is the part most desktop images get wrong, so here it is explicitly:

| Part | Source | How it stays current |
|---|---|---|
| Ubuntu + XFCE desktop | [LinuxServer.io webtop](https://docs.linuxserver.io/images/docker-webtop/) `ubuntu-xfce` | Pinned per published image; rebuild with `docker-compose.build.yml` for the newest upstream base at deploy time |
| Selkies (the streamer) | [selkies-project/selkies](https://github.com/selkies-project/selkies) | Version-pinned per published image; `SELKIES_VERSION=latest` builds the newest release |
| cloudflared (the tunnel) | [Cloudflare](https://github.com/cloudflare/cloudflared) | Baked pinned, **and** updated weekly inside the running container by itself |
| Ubuntu security patches | Ubuntu's security pocket | Applied at boot and daily, security updates only — never a feature upgrade |
| Hermes Agent | [Nous Research](https://hermes-agent.nousresearch.com) | Installed at **first boot** from upstream's installer, so you get the current release when you deploy; afterwards its own updater handles it |

Nothing here silently drifts to an untested version: the desktop platform is a
fixed, published image you can pin, and the two things that should follow upstream
(the agent, the tunnel binary) are the two things that update themselves.

## Optional: private access through Cloudflare Tunnel

1. Create a **remote-managed** Tunnel in the Cloudflare dashboard.
2. Point its public hostname at `desktop:3001` (the container name is
   `webtop-hermes`; use that if you renamed it).
3. Put a **Cloudflare Access** application in front of that hostname.
4. Paste the tunnel token into `CLOUDFLARE_TUNNEL_TOKEN` and recreate the container.

With the tunnel in place you can stop publishing `3001`/`3000` on the host
entirely, which is the strongest position: no open ports, and only identities your
Access policy allows get to the login screen.

## Updating

```bash
docker compose pull
docker compose up -d
```

Files, installed programs and the agent survive — they are on the volume. The
image also checks the registry weekly and can message you (through the agent's
Telegram) when a newer version is published; it says nothing otherwise.

The agent updates on its own schedule: `hermes update`.

## Build it yourself

```bash
./build.sh
```

`build.sh` resolves the upstream base to today's digest and pins it, so the build
is the newest base as of now *and* reproducible afterwards. If you would rather
have everything resolved at deploy time, use `docker-compose.build.yml` instead —
it takes the floating upstream tag and the newest Selkies release.

## Security notes

- The desktop user has **passwordless sudo inside the container**. That is why
  Docker's socket is not mounted here: mounting it would hand host root to anyone
  who reaches the screen.
- Session sharing is off by default, and should stay off.
- Port `3000` is plain HTTP. Use `3001`, or terminate TLS yourself.
- The generated password exists so that a one-click deployment is never a
  published machine with a known password. Read it with
  `docker exec webtop-hermes cat /config/.desktop-password`.
- Support for Ubuntu **security** updates only is deliberate: a feature upgrade
  inside a running desktop is a surprise nobody wants at 3 a.m.

## Credits and licence

Standing on other people's work, gratefully:

- [LinuxServer.io webtop](https://github.com/linuxserver/docker-webtop) — the
  Ubuntu/XFCE base image and its s6 supervision (GPL-3.0)
- [Selkies](https://github.com/selkies-project/selkies) — the WebRTC streaming
  server and browser client
- [Cloudflare cloudflared](https://github.com/cloudflare/cloudflared) — the tunnel
  connector
- [Hermes Agent](https://github.com/NousResearch/hermes-agent) — Nous Research (MIT)

The Dockerfile, boot hooks and helper scripts in this repository are licensed
**GPL-3.0**, matching the base image they build on. See [LICENSE](LICENSE).
