#!/usr/bin/env bash
# =============================================================================
# build.sh — build the published image, locally. Nothing is pushed.
# =============================================================================
# The published image is REPRODUCIBLE: the base is pinned by the digest that was
# current when you ran this script, and Selkies and cloudflared are pinned by
# version. That is the difference between this script and
# docker-compose.build.yml, which deliberately resolves everything fresh.
#
#   ./build.sh                                  # tag: webtop-hermes:dev
#   IMAGE=webtop-hermes:2026-11-04 ./build.sh
#
# Publishing is not part of this script — it needs registry credentials and is a
# separate, deliberate step:
#
#   echo "$GHCR_PUSH_TOKEN" | docker login ghcr.io -u aoio-design --password-stdin
#   docker tag webtop-hermes:2026-11-04 \
#     ghcr.io/aoio-design/webtop-ubuntu-xfce-hermes-desktop:2026-11-04
#   docker tag webtop-hermes:2026-11-04 \
#     ghcr.io/aoio-design/webtop-ubuntu-xfce-hermes-desktop:latest
#   docker push ghcr.io/aoio-design/webtop-ubuntu-xfce-hermes-desktop:2026-11-04
#   docker push ghcr.io/aoio-design/webtop-ubuntu-xfce-hermes-desktop:latest
#
# (A classic personal access token is required to push packages; fine-grained
# tokens cannot write to GHCR.)

set -euo pipefail
cd "$(dirname "$0")"

IMAGE="${IMAGE:-webtop-hermes:dev}"
BASE_TAG="${BASE_TAG:-lscr.io/linuxserver/webtop:ubuntu-xfce}"
CLOUDFLARED_VERSION="${CLOUDFLARED_VERSION:-2026.10.1}"
SELKIES_VERSION="${SELKIES_VERSION:-2.2.0}"
IMAGE_REVISION="${IMAGE_REVISION:-$(git rev-parse --short HEAD 2>/dev/null || echo unknown)}"

# Resolve the floating tag to the digest it points at RIGHT NOW, and pin that —
# so this build is the newest base as of today and still reproducible tomorrow.
echo "== resolving $BASE_TAG =="
docker pull "$BASE_TAG" >/dev/null
DIGEST="$(docker image inspect "$BASE_TAG" --format '{{index .RepoDigests 0}}' | sed 's/.*@//')"
if [ -z "$DIGEST" ]; then
  echo "could not resolve a digest for $BASE_TAG" >&2
  exit 1
fi
BASE_IMAGE="${BASE_TAG%@*}@${DIGEST}"
echo "   $BASE_IMAGE"

echo "== docker build -> $IMAGE =="
DOCKER_BUILDKIT=1 docker build \
  --pull=false \
  --build-arg BASE_IMAGE="$BASE_IMAGE" \
  --build-arg CLOUDFLARED_VERSION="$CLOUDFLARED_VERSION" \
  --build-arg SELKIES_VERSION="$SELKIES_VERSION" \
  --build-arg IMAGE_REVISION="$IMAGE_REVISION" \
  --tag "$IMAGE" \
  .

echo
echo "== baked build info =="
docker run --rm --entrypoint /bin/cat "$IMAGE" /etc/aoio-image-build-info
