# syntax=docker/dockerfile:1
# =============================================================================
# Webtop Ubuntu XFCE + Hermes Agent Desktop
# =============================================================================
# WHAT THE CONTAINER GIVES YOU
#
#   A full Ubuntu desktop (XFCE) you open in a browser tab, plus a Cloudflare
#   Tunnel connector for private remote access, plus the Hermes Agent — its CLI
#   and its desktop app — installed for you on first boot.
#
# WHERE EACH COMPONENT COMES FROM, AND HOW EACH STAYS CURRENT
#
#   base (webtop:ubuntu-xfce)   upstream tag, resolved at BUILD time. A build of
#                               this repo with no arguments takes the newest
#                               upstream base — see docker-compose.build.yml.
#                               The published image pins it by digest instead,
#                               so `docker pull` is reproducible.
#   Selkies                     version-pinned here, upgraded over whatever the
#                               base ships (the base bakes an older browser
#                               client otherwise). Override with
#                               --build-arg SELKIES_VERSION=latest.
#   cloudflared                 version-pinned here, and kept current at RUN time
#                               by a weekly in-container updater that only ever
#                               replaces the copy on the volume.
#   Hermes Agent                NOT baked. Installed at FIRST BOOT with Nous
#                               Research's own installer, into /config — so you
#                               get the newest release on the day you deploy, and
#                               it survives every container recreate. Updating it
#                               afterwards is Hermes' own updater's job.
#
# WHY HERMES IS INSTALLED AT BOOT RATHER THAN BAKED
#
#   Three reasons, in order of importance:
#
#   1. Freshness. A baked copy is frozen on the day the image was built. Installed
#      at boot, it is the current release at the moment you deploy.
#   2. It installs to the VOLUME (/config), so a container recreate — pulling a
#      newer image, changing an env var — does not throw it away.
#   3. This image redistributes none of Nous Research's code. You install it from
#      upstream, which is both cleaner and always correct.
#
#   The cost is honest: on first boot the desktop is up in under a minute and the
#   agent arrives behind it, a few minutes later (measured: ~4.5 minutes, about
#   2.5 GB on disk). Watch it with:
#
#       docker exec -it webtop-hermes tail -f /config/logs/firstboot.log
#
# WHY THE PAYLOAD LIVES AT /seed AND NOT AT /config
#
#   /config is a bind mount on your machine. A file baked at that path is hidden
#   the instant the mount lands, so the image would ship working-looking files
#   that no container ever sees. The payload is baked at /seed (an image path
#   nothing mounts over) and copied into place at boot by 10-seed-config.
#
# Reproducibility: BASE_IMAGE, SELKIES_VERSION and CLOUDFLARED_VERSION are build
# args. build.sh sets all three explicitly for the published image.

ARG BASE_IMAGE=lscr.io/linuxserver/webtop:ubuntu-xfce
FROM ${BASE_IMAGE}

# Re-declared: an ARG declared before FROM is out of scope after it, and without
# this the build-info file and the io.aoio.base.image label record an empty base.
ARG BASE_IMAGE
ARG CLOUDFLARED_VERSION=2026.10.1
ARG SELKIES_VERSION=2.2.0
ARG IMAGE_REVISION=unknown

LABEL org.opencontainers.image.title="Webtop Ubuntu XFCE + Hermes Agent Desktop" \
      org.opencontainers.image.description="Ubuntu XFCE desktop in the browser (LinuxServer webtop) with Selkies streaming, a Cloudflare Tunnel connector, and the Hermes Agent installed on first boot" \
      org.opencontainers.image.url="https://github.com/aoio-design/webtop-ubuntu-xfce-hermes-desktop" \
      org.opencontainers.image.source="https://github.com/aoio-design/webtop-ubuntu-xfce-hermes-desktop" \
      org.opencontainers.image.revision="${IMAGE_REVISION}" \
      org.opencontainers.image.licenses="GPL-3.0-only" \
      io.aoio.base.image="${BASE_IMAGE}" \
      io.aoio.cloudflared.version="${CLOUDFLARED_VERSION}" \
      io.aoio.selkies.version="${SELKIES_VERSION}"

SHELL ["/bin/bash", "-c"]
ENV DEBIAN_FRONTEND=noninteractive
# The agent's home lives on the mounted volume, which is also $HOME for the
# desktop user — so one install, one home, and it survives a recreate.
ENV HERMES_HOME=/config/.hermes

# -----------------------------------------------------------------------------
# 1. The apt packages the desktop stack and an agent's tooling need — BAKED, so
#    first boot never reaches apt. imagemagick gives `convert`/`import` (screen
#    grabs), x11-apps the X utilities, zenity the desktop dialogs.
#    05-packages re-verifies them every boot, because anything that lives only in
#    a replaced image layer disappears on recreate and then breaks things hours
#    later with an error nobody traces back here.
# -----------------------------------------------------------------------------
RUN apt-get update -qq \
 && apt-get install -y -qq --no-install-recommends \
      git curl xz-utils ca-certificates imagemagick x11-apps zenity \
      unattended-upgrades \
 && rm -rf /var/lib/apt/lists/* \
 && for b in git curl xz convert zenity; do command -v "$b" >/dev/null || { echo "missing $b"; exit 1; }; done \
 && command -v unattended-upgrade >/dev/null || { echo "missing unattended-upgrade"; exit 1; }

# -----------------------------------------------------------------------------
# 2. cloudflared, at BUILD time, pinned by version. A first-boot download of a
#    binary this machine then executes is a supply-chain step better done here
#    once, and pinned. 19-cloudflared-update keeps it current afterwards.
# -----------------------------------------------------------------------------
RUN curl -fsSL -o /tmp/cloudflared.deb \
      "https://github.com/cloudflare/cloudflared/releases/download/${CLOUDFLARED_VERSION}/cloudflared-linux-amd64.deb" \
 && dpkg -i /tmp/cloudflared.deb >/dev/null \
 && rm -f /tmp/cloudflared.deb \
 && cloudflared --version

# -----------------------------------------------------------------------------
# 2b. Selkies, upgraded on top of the base image.
#
#     Why this is a build step and not a runtime one: pip installing into the
#     container layer at boot would be lost on every recreate, would run on every
#     start, and would make the streamer depend on PyPI's uptime.
#
#     Why the dashboard source and not /usr/share/selkies/web: nginx does not
#     proxy the browser client, it serves /usr/share/selkies/web off disk, and
#     init-nginx REBUILDS that directory on EVERY container start with
#       rm -Rf /usr/share/selkies/web
#       cp -a /usr/share/selkies/$DASHBOARD /usr/share/selkies/web
#     (DASHBOARD defaults to selkies-dashboard). Anything written to `web` is
#     wiped at the next start. The directory init-nginx copies FROM is the
#     durable place to put the upgraded client.
#
#     Pass --build-arg SELKIES_VERSION=latest to take the newest PyPI release
#     instead of the pin.
# -----------------------------------------------------------------------------
RUN set -e; \
    SPEC="selkies==${SELKIES_VERSION}"; \
    [ "$SELKIES_VERSION" = "latest" ] && SPEC="selkies"; \
    /lsiopy/bin/python3 -m pip install --no-cache-dir --only-binary=:all: "$SPEC"; \
    WEB="$(/lsiopy/bin/python3 -c 'import os, selkies; print(os.path.join(os.path.dirname(selkies.__file__), "selkies_web"))')"; \
    test -f "$WEB/index.html" || { echo "selkies web client missing at $WEB"; exit 1; }; \
    rm -rf /usr/share/selkies/selkies-dashboard; \
    cp -a "$WEB" /usr/share/selkies/selkies-dashboard; \
    echo "selkies:  $(/lsiopy/bin/selkies --version)"; \
    echo "client:   $(grep -oE 'assets/index-[A-Za-z0-9_-]+\.js' /usr/share/selkies/selkies-dashboard/index.html | head -1)"

# -----------------------------------------------------------------------------
# 3. The seed payload for the mounted /config volume.
# -----------------------------------------------------------------------------
COPY seed/config/ /seed/config/

# -----------------------------------------------------------------------------
# 4. The boot hooks. LinuxServer's init-custom-files service runs everything in
#    /custom-cont-init.d in filename order (verified in the base image:
#    /etc/s6-overlay/s6-rc.d/init-custom-files/run loops /bin/bash over the glob,
#    sequentially, and init-services depends on it — so cron, nginx, Selkies and
#    the desktop start only after these have finished).
#
#      05-packages         verify the baked packages; repair only if one is missing
#      07-security-update  re-apply the security patches a recreate erased (detached)
#      08-desktop-password replace a placeholder PASSWORD with a generated one
#      10-seed-config      payload -> /config (only when the target is absent)
#      12-cloudflared-volume  keep cloudflared on the volume; newer wins
#      15-timezone         put the clock on your time zone (/config/.timezone)
#      17-security-update-cron  put the daily security patch run on the schedule
#      18-update-watch     put the update watcher on the schedule
#      19-cloudflared-update  put the weekly connector updater on the schedule
#      20-crontab-install  install /config/crontabs/abc for abc and kick svc-cron
#      25-cloudflared-tunnel  store a provided run token privately and start the
#                          connector; a blank/placeholder token means disabled
#      40-hermes-glue      make the machine a sane host for a supervised agent
#      90-firstboot        install the Hermes CLI + desktop app, in the background
# -----------------------------------------------------------------------------
COPY custom-cont-init.d/ /custom-cont-init.d/
RUN chmod 755 /custom-cont-init.d/*

# -----------------------------------------------------------------------------
# 5. Helpers the hooks use. Also runnable by hand, which is how they are tested.
# -----------------------------------------------------------------------------
COPY bin/aoio-ask-timezone /usr/local/bin/aoio-ask-timezone
COPY bin/aoio-cloudflared-watchdog /usr/local/bin/aoio-cloudflared-watchdog
# Tells the owner in chat when a newer version of this image is published
# (silent otherwise); cron line appended at boot by 18-update-watch.
COPY bin/aoio-update-watch /usr/local/bin/aoio-update-watch
# Keeps the connector current by replacing /config/bin/cloudflared; silent unless
# an update failed and was reverted. Cron line added by 19-cloudflared-update.
COPY bin/aoio-cloudflared-update /usr/local/bin/aoio-cloudflared-update
# Applies Ubuntu SECURITY updates only (never feature upgrades). Run detached at
# boot by 07-security-update and daily from cron by 17-security-update-cron.
COPY bin/aoio-security-update /usr/local/bin/aoio-security-update
# One real install of the Hermes CLI + desktop app, run by 90-firstboot.
COPY bin/aoio-firstboot-install /usr/local/bin/aoio-firstboot-install
RUN chmod 755 /usr/local/bin/aoio-ask-timezone /usr/local/bin/aoio-cloudflared-watchdog \
              /usr/local/bin/aoio-update-watch /usr/local/bin/aoio-cloudflared-update \
              /usr/local/bin/aoio-security-update /usr/local/bin/aoio-firstboot-install

# -----------------------------------------------------------------------------
# 6. Assert the image is what we think it is, and record what went in.
#    The negative assertions matter as much as the positive ones.
# -----------------------------------------------------------------------------
RUN set -e; \
    for f in /seed/config/crontabs/abc /seed/config/cron-notify.sh \
             /seed/config/Desktop/chromium.desktop /seed/config/Desktop/hermes-agent.desktop \
             /seed/config/.config/autostart/hermes-agent.desktop \
             /seed/config/start-hermes-desktop.sh \
             /custom-cont-init.d/05-packages /custom-cont-init.d/07-security-update \
             /custom-cont-init.d/08-desktop-password /custom-cont-init.d/10-seed-config \
             /custom-cont-init.d/12-cloudflared-volume /custom-cont-init.d/15-timezone \
             /custom-cont-init.d/17-security-update-cron /custom-cont-init.d/18-update-watch \
             /custom-cont-init.d/19-cloudflared-update /custom-cont-init.d/20-crontab-install \
             /custom-cont-init.d/25-cloudflared-tunnel /custom-cont-init.d/40-hermes-glue \
             /custom-cont-init.d/90-firstboot \
             /usr/local/bin/aoio-ask-timezone /usr/local/bin/aoio-cloudflared-watchdog \
             /usr/local/bin/aoio-firstboot-install /usr/local/bin/aoio-security-update; do \
      test -f "$f" || { echo "MISSING PAYLOAD: $f"; exit 1; }; \
    done; \
    for f in /custom-cont-init.d/*; do test -x "$f" || { echo "NOT EXECUTABLE: $f"; exit 1; }; done; \
    test -x /usr/local/bin/aoio-ask-timezone; \
    test -x /usr/local/bin/aoio-cloudflared-watchdog; \
    test -x /usr/local/bin/aoio-cloudflared-update; \
    test -x /usr/local/bin/aoio-firstboot-install; \
    test -x /usr/local/bin/aoio-security-update; \
    command -v unattended-upgrade >/dev/null; \
    command -v zenity >/dev/null; \
    if [ "$SELKIES_VERSION" != "latest" ]; then \
      test "$(/lsiopy/bin/selkies --version 2>/dev/null | awk '{print $2}')" = "${SELKIES_VERSION}" \
        || { echo "selkies is not ${SELKIES_VERSION}"; exit 1; }; \
    fi; \
    grep -q "over the stream" /usr/share/selkies/selkies-dashboard/assets/index-*.js \
      || { echo "the dashboard source is not the upgraded client"; exit 1; }; \
    grep -q "__SELKIES_UI_LAYOUT__" /usr/share/selkies/selkies-dashboard/assets/index-*.js \
      || { echo "the dashboard source is not the 2.2+ client (no UI layout switch)"; exit 1; }; \
    command -v cloudflared >/dev/null; \
    test -x /usr/bin/chromium || test -x /usr/bin/chromium-browser; \
    ! test -e /seed/config/.config/autostart/aoio-timezone.desktop \
      || { echo "the clock callout must be gone from the seed"; exit 1; }; \
    ! test -e /seed/studio || { echo "no studio belongs in this image"; exit 1; }; \
    ! test -e /seed/config/.hermes || { echo "the agent home must not be seeded — it is installed at boot"; exit 1; }; \
    printf 'base=%s\ncloudflared=%s\nselkies=%s\nimage_revision=%s\nbuilt=%s\n' \
      "$BASE_IMAGE" "$CLOUDFLARED_VERSION" "$SELKIES_VERSION" "$IMAGE_REVISION" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      > /etc/aoio-image-build-info; \
    cat /etc/aoio-image-build-info
