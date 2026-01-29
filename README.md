# Next.js Docker Application

A minimal Next.js application with a production-ready multi-stage Dockerfile.

## Project Structure

```
.
├── Dockerfile              # Multi-stage production Dockerfile
├── .dockerignore           # Files excluded from Docker build context
├── .github/
│   └── workflows/
│       └── docker-build.yml  # GitHub Actions CI configuration
├── .gitlab-ci.yml          # GitLab CI configuration
├── package.json
├── package-lock.json
├── next.config.js
├── tsconfig.json
└── src/
    └── app/
        ├── layout.tsx
        └── page.tsx
```

## Build Instructions

### Local Development

```bash
# Install dependencies
npm install

# Run development server
npm run dev
```

### Local Docker Build

```bash
# Basic build
docker build -t nextjs-app .

# Build with all metadata arguments
docker build \
  --build-arg CI=true \
  --build-arg GIT_COMMIT=$(git rev-parse HEAD) \
  --build-arg GIT_URL=$(git remote get-url origin) \
  --build-arg BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --build-arg BUILD_IMAGE=nextjs-app:local \
  -t nextjs-app:local .

# Run the container
docker run -p 3000:3000 nextjs-app
```

### Multi-Platform Build (for CI)

```bash
# Create a buildx builder
docker buildx create --name multiplatform --use

# Build for multiple platforms
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg CI=true \
  --build-arg GIT_COMMIT=$(git rev-parse HEAD) \
  --build-arg BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ) \
  -t your-registry/nextjs-app:latest \
  --push .
```

---

## CI Environment Build Instructions

### GitHub Actions

The `.github/workflows/docker-build.yml` file is pre-configured. It will:

1. **On Push to main/master**: Build and push to GitHub Container Registry (ghcr.io)
2. **On Pull Request**: Build only (no push) for validation

**Setup steps:**
1. Push this repository to GitHub
2. Go to Settings → Actions → General → Workflow permissions
3. Enable "Read and write permissions"
4. The workflow runs automatically on push/PR

**Manual trigger via GitHub CLI:**
```bash
gh workflow run docker-build.yml
```

### GitLab CI

The `.gitlab-ci.yml` file is pre-configured. It will:

1. Build the Docker image on every commit
2. Push to GitLab Container Registry

**Setup steps:**
1. Push this repository to GitLab
2. Go to Settings → CI/CD → Variables
3. Ensure `CI_REGISTRY`, `CI_REGISTRY_USER`, `CI_REGISTRY_PASSWORD` are available (auto-provided by GitLab)
4. Pipeline runs automatically on push

### Jenkins

```groovy
pipeline {
    agent any
    
    environment {
        REGISTRY = 'your-registry.com'
        IMAGE_NAME = 'nextjs-app'
    }
    
    stages {
        stage('Build') {
            steps {
                script {
                    docker.build("${REGISTRY}/${IMAGE_NAME}:${env.BUILD_NUMBER}", """
                        --build-arg CI=true
                        --build-arg GIT_COMMIT=${env.GIT_COMMIT}
                        --build-arg GIT_URL=${env.GIT_URL}
                        --build-arg BUILD_URL=${env.BUILD_URL}
                        --build-arg BUILD_DATE=\$(date -u +%Y-%m-%dT%H:%M:%SZ)
                        --build-arg BUILD_IMAGE=${REGISTRY}/${IMAGE_NAME}:${env.BUILD_NUMBER}
                        .
                    """)
                }
            }
        }
        
        stage('Push') {
            steps {
                script {
                    docker.withRegistry("https://${REGISTRY}", 'registry-credentials') {
                        docker.image("${REGISTRY}/${IMAGE_NAME}:${env.BUILD_NUMBER}").push()
                        docker.image("${REGISTRY}/${IMAGE_NAME}:${env.BUILD_NUMBER}").push('latest')
                    }
                }
            }
        }
    }
}
```

### Generic CI Script

For any CI system, use this build script:

```bash
#!/bin/bash
set -e

# Configuration
REGISTRY="${REGISTRY:-docker.io}"
IMAGE_NAME="${IMAGE_NAME:-nextjs-app}"
TAG="${TAG:-$(git rev-parse --short HEAD)}"

# Build arguments
BUILD_ARGS=(
    --build-arg CI=true
    --build-arg "PR=${PR:-}"
    --build-arg "GIT_COMMIT=$(git rev-parse HEAD)"
    --build-arg "GIT_URL=$(git remote get-url origin 2>/dev/null || echo 'unknown')"
    --build-arg "BUILD_URL=${BUILD_URL:-}"
    --build-arg "BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    --build-arg "BUILD_IMAGE=${REGISTRY}/${IMAGE_NAME}:${TAG}"
)

# Build
echo "Building ${REGISTRY}/${IMAGE_NAME}:${TAG}"
docker build "${BUILD_ARGS[@]}" -t "${REGISTRY}/${IMAGE_NAME}:${TAG}" .

# Tag as latest if on main branch
if [ "${BRANCH:-$(git branch --show-current)}" = "main" ] || [ "${BRANCH}" = "master" ]; then
    docker tag "${REGISTRY}/${IMAGE_NAME}:${TAG}" "${REGISTRY}/${IMAGE_NAME}:latest"
fi

# Push (if PUSH=true)
if [ "${PUSH:-false}" = "true" ]; then
    docker push "${REGISTRY}/${IMAGE_NAME}:${TAG}"
    if [ "${BRANCH:-$(git branch --show-current)}" = "main" ] || [ "${BRANCH}" = "master" ]; then
        docker push "${REGISTRY}/${IMAGE_NAME}:latest"
    fi
fi

echo "Build complete: ${REGISTRY}/${IMAGE_NAME}:${TAG}"
```

---

## Dockerfile Features

| Feature | Description |
|---------|-------------|
| **Multi-stage build** | 4 stages (base, deps, build, release) for minimal final image |
| **Network resilience** | npm configured with extended timeouts and retries |
| **SWC optimization** | Removes unused SWC platform binaries |
| **Non-root user** | Runs as `nextjs` user in production |
| **Build metadata** | Labels and env vars for traceability |
| **Cache optimization** | Separate deps stage for better layer caching |
| **Production mode** | `NODE_ENV=production` with pruned devDependencies |

## Build Arguments

| Argument | Description | Default |
|----------|-------------|---------|
| `CI` | CI environment flag | `true` |
| `PR` | Pull request number | - |
| `NODE_ENV_ARG` | Node environment | `production` |
| `GIT_URL` | Repository URL | - |
| `GIT_COMMIT` | Git commit SHA | - |
| `BUILD_URL` | CI build URL | - |
| `BUILD_DATE` | Build timestamp | - |
| `BUILD_IMAGE` | Full image name with tag | - |

