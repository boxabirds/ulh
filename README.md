# ulh — Ultra Light Hosting

Deploy any project to `<name>.<your-domain>` with one command.

Built for POCs. No config files per project, no CI pipelines, no YAML. Just `ulh deploy`.

## Install

```bash
git clone https://github.com/boxabirds/ulh.git
cd ulh
sudo ./install.sh
```

Requires [wrangler](https://developers.cloudflare.com/workers/wrangler/install-and-setup/) (`npm install -g wrangler`).

## Setup

```bash
ulh setup
```

You'll be prompted for:

| Value | Example | Where to find it |
|---|---|---|
| Domain | `ulh.life` | The domain you want to host under |
| Account ID | `abc123...` | Dashboard overview sidebar, or in the URL |
| Zone ID | `def456...` | Your domain's overview page sidebar |
| API Token | `xyz789...` | My Profile → API Tokens → Create Token |

The API token needs these permissions:
- **Cloudflare Pages: Edit**
- **DNS: Edit**
- **Zone: Read**

## Usage

```bash
# Deploy the current directory
ulh deploy

# Deploy a specific folder
ulh deploy ~/projects/my-poc

# List all deployed projects
ulh list

# Delete a project
ulh delete my-poc
```

## Project detection

ulh detects your project type and handles the build automatically:

| Type | Detection | Build | Deploys |
|---|---|---|---|
| React (Vite) | `package.json` has `react` + `vite` | `npm run build` | `dist/` |
| React (CRA) | `package.json` has `react-scripts` | `npm run build` | `build/` |
| Static HTML | Everything else | None | Folder as-is |

## How it works

1. Checks your git working tree is clean (warns if not)
2. Detects project type and builds if needed
3. Creates a Cloudflare Pages project (if first deploy)
4. Deploys via `wrangler pages deploy`
5. Attaches `<name>.<your-domain>` as a custom domain via the Cloudflare API

Project names are derived from the git remote or directory name.

## License

MIT
