<p align="center">
  <img src="assets/banner.svg" width="830" alt="coconut-envdiff banner">
</p>
<p align="center">
  <a href="https://github.com/Celine1337/coconut-envdiff/releases"><img src="assets/nav-releases.svg" alt="Releases"></a>
  <a href="https://coconut-lang.org/"><img src="assets/nav-spec.svg" alt="Coconut docs"></a>
  <a href="LICENSE"><img src="assets/nav-mit.svg" alt="MIT"></a>
</p>

<img src="assets/section-about.svg" width="830" alt="About">

**coconut-envdiff** compares two `.env` files and tells you what changed — `+ KEY` for keys added in the second file, `- KEY` for keys removed, and `~ KEY` for keys whose value changed — sorted within each group, followed by an `X added, Y removed, Z changed` summary. It is built for CI and for reviewing config drift: it parses `KEY=value` lines, ignores `#` comments and blank lines, strips an optional `export ` prefix, and removes matching surrounding quotes from values. Crucially, it **only ever prints key names, never values**, so you can diff a production `.env` against a staging one in a pipeline without leaking a single secret.

Why Coconut? Coconut is a functional superset of Python that compiles to plain Python, so this tool reads like a small data-flow program — a `match` expression classifies each line and a `|>` pipeline turns the file into a dict — while still running anywhere Python does. `pip install coconut` gives you `coconut-run`, and a single `.coconut` file is the whole tool. No dependencies beyond the standard library.

<img src="assets/section-features.svg" width="830" alt="Features">

- **Three-way key diff** — added (`+`), removed (`-`) and changed (`~`), each group sorted by key for stable, reviewable output.
- **Secrets stay secret** — only key names are printed; values are compared in memory and never written to stdout.
- **Real `.env` parsing** — skips `#` comments and blank lines, strips a leading `export `, and removes matching surrounding single/double quotes; last assignment wins on duplicate keys.
- **CI-ready exit codes** — `0` when the files match, `1` when there is any difference (gate a deploy on it), `2` for a missing file or bad usage.
- **Concise summary** — a final `X added, Y removed, Z changed` line for logs and dashboards.
- **Zero dependencies & tested** — one Coconut file; a self-contained `test.sh` builds fixtures and asserts exit codes, output, and that secret values never leak.

<img src="assets/section-stack.svg" width="830" alt="Tech stack">

<img src="assets/section-install.svg" width="830" alt="Install">

Requires [Coconut](https://coconut-lang.org/) 3.x (`pip install coconut`), which runs on Python 3.9+.

```bash
git clone https://github.com/Celine1337/coconut-envdiff.git
cd coconut-envdiff
./build.sh          # writes a launcher at bin/coconut-envdiff
./bin/coconut-envdiff a.env b.env
```

Or run the source directly, no build at all:

```bash
coconut-run src/main.coconut a.env b.env
```

<img src="assets/section-usage.svg" width="830" alt="Usage">

```bash
coconut-envdiff a.env b.env       # diff two .env files by key
echo $?                           # 0 = identical, 1 = differences, 2 = bad usage
```

```text
$ coconut-envdiff staging.env prod.env
+ NEW_FEATURE_FLAG
- LEGACY_TIMEOUT
~ DATABASE_URL
~ LOG_LEVEL
1 added, 1 removed, 2 changed
```

Values are never shown — `DATABASE_URL` may differ by a password, but only the key name appears.

Exit codes: `0` no differences, `1` any difference, `2` missing file or bad usage.

<img src="assets/section-license.svg" width="830" alt="License">

MIT — see [LICENSE](LICENSE).