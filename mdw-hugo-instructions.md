# Hugo Development Environment Setup Instructions

Instructions for setting up the FortiHugo development environment to render Hugo content locally.

## Prerequisites

### 1. Install Docker Desktop

#### Download the correct version:
- Go to: https://www.docker.com/products/docker-desktop/
- Click "Download for Mac"
- **Important:** Select the correct chip architecture:
  - **Apple Silicon** (M1/M2/M3/M4 chips): Download "Mac with Apple chip"
  - **Intel Mac**: Download "Mac with Intel chip"
- To check your Mac's chip: Apple menu () → About This Mac → look for "Chip" (Apple Silicon) or "Processor" (Intel)

#### Install Docker Desktop:
1. Open the downloaded `Docker.dmg` file
2. Drag the Docker icon to the Applications folder
3. Open Docker from Applications (or Spotlight search)
4. If prompted, click "Open" to confirm you want to open the app
5. Accept the Docker Subscription Service Agreement
6. Docker will request privileged access - enter your macOS password when prompted

#### Initial configuration:
1. Wait for Docker to start (whale icon in menu bar will animate, then become steady)
2. Click the whale icon in the menu bar → Settings (gear icon)
3. **Resources → File Sharing**: Ensure your home directory or project paths are listed
   - Add `/Users/your-username/github` if not present
4. **Resources → Advanced**: Adjust CPU/Memory if needed (defaults are usually fine)
5. Click "Apply & Restart" if you made changes

#### Verify installation:
```bash
# Check Docker version
docker --version

# Check Docker is running properly
docker info

# Test with hello-world container
docker run hello-world
```

You should see output confirming Docker is installed and running. The hello-world container will print a success message.

### 2. Install Node.js and npm
- Download from: https://nodejs.org/ (LTS version recommended)
- Or use Homebrew on macOS: `brew install node`
- Verify: `node --version && npm --version`

### 3. Install Git
- macOS: `xcode-select --install` or `brew install git`
- Verify: `git --version`

## Step 1: Clone the Repository

```bash
cd ~/github  # or your preferred directory
git clone https://github.com/your-org/fortinet-ui-terraform.git
cd fortinet-ui-terraform
```

## Step 2: Pull the FortiHugo Docker Image

The image is available from AWS ECR public registry:

```bash
docker pull public.ecr.aws/k4n6m5h8/fortinet-hugo:latest
docker tag public.ecr.aws/k4n6m5h8/fortinet-hugo:latest fortinet-hugo:latest
```

## Step 3: Install npm Dependencies

```bash
npm install
```

This installs `cross-env` which handles cross-platform environment variables.

## Step 4: Create Required Directories

```bash
mkdir -p docs
mkdir -p layouts/shortcodes
```

## Step 5: Run Hugo to Build/Preview Content

### Build the static site:
```bash
npm run hugo
```

This runs the Docker container which:
- Mounts your `content/` directory
- Mounts your `config.toml` (if present, otherwise uses CentralRepo defaults)
- Mounts your `layouts/` for custom shortcodes
- Outputs the built site to `docs/`

### For live preview with hot reload (alternative):
```bash
docker run --rm -it \
  -p 1313:1313 \
  -v $(pwd)/content/:/home/CentralRepo/content \
  -v $(pwd)/layouts:/home/UserRepo/layouts \
  fortinet-hugo:latest \
  hugo server --bind 0.0.0.0
```

Then open http://localhost:1313 in your browser.

## Directory Structure Reference

```
fortinet-ui-terraform/
├── content/                  # Hugo markdown content
│   ├── _index.md
│   ├── 1_Introduction/
│   ├── 2_Getting_Started/
│   └── ...
├── layouts/
│   └── shortcodes/          # Custom Hugo shortcodes
├── docs/                    # Generated static site output
├── package.json             # npm scripts (npm run hugo)
└── config.toml              # Hugo configuration (optional)
```

## Troubleshooting

### Docker not running:
```bash
# Check Docker status
docker info
# If not running, start Docker Desktop application
```

### Permission issues on macOS:
```bash
# Ensure Docker has file sharing enabled for your project directory
# Docker Desktop → Settings → Resources → File Sharing
```

### Image not found:
```bash
# Verify image exists
docker images | grep fortinet-hugo

# Re-pull if needed
docker pull public.ecr.aws/k4n6m5h8/fortinet-hugo:latest
```

### npm run hugo fails:
```bash
# Ensure cross-env is installed
npm install

# Or run docker command directly
docker run --rm -it \
  -v $(pwd)/content/:/home/CentralRepo/content \
  -v $(pwd)/docs:/home/CentralRepo/public \
  -v $(pwd)/layouts:/home/UserRepo/layouts \
  fortinet-hugo:latest
```

## Quick Reference

| Command | Description |
|---------|-------------|
| `npm run hugo` | Build static site to docs/ |
| `docker images \| grep hugo` | List Hugo Docker images |
| `docker pull public.ecr.aws/k4n6m5h8/fortinet-hugo:latest` | Pull latest image |

## Notes

- The `fortinet-hugo` Docker image contains Hugo, the CentralRepo theme/templates, and all required dependencies
- The CentralRepo source: https://github.com/FortinetCloudCSE/CentralRepo
- Built content goes to `docs/` directory which is used for GitHub Pages deployment
