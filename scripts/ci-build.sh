#!/bin/bash
set -e

# CI Build Script for Docker
# Usage: ./scripts/ci-build.sh [--push]

# Configuration (override via environment variables)
REGISTRY="${REGISTRY:-docker.io}"
IMAGE_NAME="${IMAGE_NAME:-nextjs-app}"
TAG="${TAG:-$(git rev-parse --short HEAD 2>/dev/null || echo 'latest')}"
PLATFORM="${PLATFORM:-linux/amd64}"

# Parse arguments
PUSH=false
for arg in "$@"; do
    case $arg in
        --push)
            PUSH=true
            shift
            ;;
    esac
done

# Build arguments
BUILD_ARGS=(
    --build-arg CI=true
    --build-arg "PR=${PR:-}"
    --build-arg "GIT_COMMIT=$(git rev-parse HEAD 2>/dev/null || echo 'unknown')"
    --build-arg "GIT_URL=$(git remote get-url origin 2>/dev/null || echo 'unknown')"
    --build-arg "BUILD_URL=${BUILD_URL:-}"
    --build-arg "BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    --build-arg "BUILD_IMAGE=${REGISTRY}/${IMAGE_NAME}:${TAG}"
)

FULL_IMAGE="${REGISTRY}/${IMAGE_NAME}:${TAG}"

echo "=============================================="
echo "Docker Build Configuration"
echo "=============================================="
echo "Registry:    ${REGISTRY}"
echo "Image:       ${IMAGE_NAME}"
echo "Tag:         ${TAG}"
echo "Full Image:  ${FULL_IMAGE}"
echo "Platform:    ${PLATFORM}"
echo "Push:        ${PUSH}"
echo "=============================================="

# Build
echo ""
echo "🔨 Building Docker image..."
docker build \
    --platform "${PLATFORM}" \
    "${BUILD_ARGS[@]}" \
    -t "${FULL_IMAGE}" \
    .

# Tag as latest if on main/master branch
BRANCH="${BRANCH:-$(git branch --show-current 2>/dev/null || echo 'unknown')}"
if [ "${BRANCH}" = "main" ] || [ "${BRANCH}" = "master" ]; then
    echo "📌 Tagging as latest..."
    docker tag "${FULL_IMAGE}" "${REGISTRY}/${IMAGE_NAME}:latest"
fi

# Push if requested
if [ "${PUSH}" = "true" ]; then
    echo ""
    echo "🚀 Pushing to registry..."
    docker push "${FULL_IMAGE}"
    
    if [ "${BRANCH}" = "main" ] || [ "${BRANCH}" = "master" ]; then
        docker push "${REGISTRY}/${IMAGE_NAME}:latest"
    fi
fi

echo ""
echo "✅ Build complete: ${FULL_IMAGE}"

