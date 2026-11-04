# Submission text

Copy-paste fields for the Hostinger open-source partners submission
(<https://hpanel.hostinger.com/developer-program>).

---

## Project name

```
Webtop Ubuntu XFCE + Hermes Agent Desktop
```

## Repository

```
https://github.com/aoio-design/webtop-ubuntu-xfce-hermes-desktop
```

## One-line description

```
A full Ubuntu XFCE desktop you open in a browser tab, with a Cloudflare Tunnel connector and the Hermes Agent installed on first boot.
```

## Short description (catalogue card)

```
A complete Ubuntu Linux desktop in your browser — persistent home folder, Chromium, terminal, optional private access through a Cloudflare Tunnel, and the Hermes Agent (CLI and desktop app) installed automatically on first boot.
```

## Full description

```
Webtop Ubuntu XFCE + Hermes Agent Desktop gives you a complete Linux desktop on
your own server, opened in any modern browser tab. There is nothing to install on
the machine you are sitting at — no VNC viewer, no RDP client, no VPN. Start the
container, open https://your-server:3001, and you have an XFCE desktop on Ubuntu
with a Chromium browser, a terminal, a file manager and a home folder that
persists across container updates.

WHAT YOU CAN DO WITH IT

- Work on a real Linux desktop from a laptop, tablet or another computer, from
  anywhere, without installing anything on the device you are using.
- Keep your files, settings and installed programs in a persistent volume that
  survives image updates and container recreates.
- Leave long jobs running 24/7 — builds, downloads, scheduled scripts, a long
  agent task — while you are disconnected, then come back to the same desktop.
- Reach the desktop privately through a Cloudflare Tunnel with no ports open on
  your server, optionally behind Cloudflare Access.
- Run the Hermes Agent: its CLI and its desktop app are installed for you on first
  boot, with an icon on the desktop. Bring your own API keys.
- Stay patched without thinking about it: Ubuntu security updates are applied at
  boot and daily, on the machine's own schedule.

COMPONENTS THIS PACKAGE IS BUILT FROM

- LinuxServer.io webtop:ubuntu-xfce — the Ubuntu, XFCE, s6-overlay process
  supervision, nginx login and Chromium base (pinned by digest; GPL-3.0).
- Selkies — the WebRTC streaming server and browser client that carry the desktop
  to your browser (version-pinned, upgraded over the base image's older client).
- Cloudflare cloudflared — the Tunnel connector, for private remote access with no
  published ports (version-pinned, and updated weekly inside the running
  container).
- Ubuntu unattended security updates plus a daily cron run — security pocket only,
  never a feature upgrade.
- Hermes Agent (Nous Research) — installed at first boot with upstream's own
  installer, into the mounted volume, so it is the current release on the day you
  deploy and survives every recreate.
- A small set of boot hooks: seed the home folder only when it is empty, restore
  the saved time zone, keep the tunnel connector current, restart it if it exits,
  guarantee the desktop login is never left on a placeholder password, and install
  the machine's crontab.

HOW EACH PART STAYS CURRENT

The desktop platform (base image and streamer) is pinned per published release, so
a deploy is reproducible. The two components that should follow upstream do so by
themselves or at deploy time: the tunnel binary updates weekly inside the container,
and the agent is installed from upstream on first boot. A build-from-source compose
file is included for anyone who wants every upstream piece resolved at deploy time.

RUNTIME NOTES

- Architecture: linux/amd64
- Ports: 3001 (HTTPS, self-signed certificate by default), 3000 (plain HTTP for a
  TLS-terminating proxy)
- Volumes: /config (the desktop's home — back this up) and /shared
- Needs shm_size of about 2 GB for Chromium
- First boot: desktop usable in under a minute; the agent installs in the
  background over the next few minutes
```

## Suggested category

```
Productivity  (also fits: Developer tools, Infrastructure)
```

## Tags

```
ubuntu, xfce, webtop, linux-desktop, remote-desktop, browser-desktop, webrtc, selkies, cloudflare-tunnel, hermes-agent
```

## Deploy button (once the partner code exists)

Replace `YOUR_PARTNER_CODE` with the code hPanel gives you:

```markdown
[![Deploy on Hostinger](https://assets.hostinger.com/vps/deploy.svg)](https://www.hostinger.com/deploy?template=aoio-design/webtop-ubuntu-xfce-hermes-desktop&ref=YOUR_PARTNER_CODE)
```
