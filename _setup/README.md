# Archive setup

Run from the generated static mirror repo root:

```sh
_setup/getArchives.sh
```

Input: `_setup/archive-urls.txt`. Output: `get/*.tgz`.

Options:

```sh
_setup/getArchives.sh --force
ARCHIVE_DOWNLOAD_JOBS=15 _setup/getArchives.sh
```

Logs are written to `_setup/logs/`. Web access to `_setup/` is denied.
