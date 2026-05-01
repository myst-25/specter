# Contributing to Yurikey Manager

## Development Setup

```sh
git clone https://github.com/Yurii0307/yurikey.git
cd yurikey
npm ci
```

Requirements: Node.js >= 20, npm >= 9.

## Building

```sh
npm run build
```

This runs:
1. `vite build` — bundles WebUI (MWC + JS + CSS) into `Module/webroot/`
2. Copies shell scripts, libs, features, pipelines from `src/` to `Module/`
3. Zips `Module/` → `module.zip`

Output: `module.zip` — flashable Magisk/KernelSU/APatch module.

## WebUI Development

For hot-reload during WebUI development:

```sh
npm run dev
```

This starts Vite's dev server. Edit files in `src/webroot/` and changes reflect instantly.

## Shell Scripts

All shell scripts live in `src/`. Run ShellCheck before committing:

```sh
find src/ -name '*.sh' -exec shellcheck {} +
```

### Adding a New Feature

1. Create a new file in `src/features/<name>.sh`
2. Follow the feature script contract (MODDIR, sourcing, `exit 0`)
3. Add it to a pipeline in `src/pipelines/` if it should run automatically
4. Add a WebUI button in `src/webroot/index.html` with `data-script="<name>.sh"`

### Adding a Translation

1. Edit `src/webroot/lang/source/string.json` with the new English string
2. Tag the string with a `data-i18n` or `data-i18n-label` attribute in HTML
3. Submit translations via the project's Crowdin page

## Pull Request Process

1. Branch from `rewrite`
2. Make changes only in `src/` — never `Module/` or `module/`
3. Run `npm run build` and verify it succeeds
4. Open a PR against the `rewrite` branch
5. Include a clear description of what the change does
