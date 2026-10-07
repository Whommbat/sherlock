# OSINT stack

One-shot build of six OSINT tools on a Linux host, each in its own
virtualenv with a wrapper on `PATH`.

| Tool | Source | Python | Wrapper(s) |
|------|--------|--------|------------|
| sherlock | this repo | 3.12 | `sherlock` |
| blackbird | antoniaci/blackbird | 3.12 | `blackbird` |
| maigret | soxoj/maigret | 3.12 | `maigret` |
| spiderfoot | smicallef/spiderfoot | 3.11 | `spiderfoot`, `sfcli` |
| theHarvester | laramies/theHarvester | 3.14 | `theHarvester`, `harvestview`, `harvest-report` |
| shodan | achillean/shodan-python | 3.12 | `shodan` |

## Install

```bash
git clone https://github.com/Whommbat/sherlock ~/sherlock
~/sherlock/osint-stack/install.sh            # add --with-browser for theHarvester's Chromium
echo 'export PATH="$HOME/osint/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
```

Needs `git` and `curl`. The script installs `uv`, which then fetches the
three Python versions itself, so the host's system Python does not matter.
Set `OSINT_HOME` to install somewhere other than `~/osint`. Re-running is
safe and is how you upgrade after bumping a pinned commit in `install.sh`.

## Layout

```
~/osint/
  src/      upstream checkouts, pinned by commit
  venvs/    one virtualenv per tool
  bin/      wrappers (put this on PATH)
  data/     spiderfoot database, logs, cache
```

## Notes per tool

- **spiderfoot** with no arguments starts the web UI on
  `http://127.0.0.1:5001`. Pass `-l 0.0.0.0:5001` to reach it from the LAN.
  Its pinned upstream deps only have wheels through Python 3.11, hence the
  separate interpreter.
- **theHarvester** reads provider keys from `~/.theHarvester/api-keys.yaml`
  (template in `src/theHarvester/theHarvester/data/`). `harvestview` wants
  `THEHARVESTER_API_KEY` set before it starts. Sources that drive a browser
  need `--with-browser` at install time.
- **blackbird** writes results under `src/blackbird/results/` because it
  resolves paths from its working directory; the wrapper cd's there for you.
- **shodan** needs `shodan init <API_KEY>` once. Its CLI still imports
  `pkg_resources`, so the venv pins `setuptools<81`.
- **maigret** is installed without the optional `[pdf]` extra (needs libcairo).
  Add `'maigret[pdf]'` to its install line if you want PDF reports.

## Pinned commits

| Tool | Commit | Upstream date |
|------|--------|---------------|
| blackbird | `b45505080ef5` | 2025-07-13 |
| maigret | `5b590c4ff3da` | 2026-10-07 |
| spiderfoot | `0f815a203afe` | 2023-11-05 |
| theHarvester | `49a38f8d33c3` | 2026-10-02 |
| shodan-python | `87a0688d1e5b` | 2023-12-16 |
