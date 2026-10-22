## Attempt 01 — local harness failure

The build stopped before `make` or any probe ran because macOS `/usr/bin/time` does not support the Linux-only `-v` option. `localrun` recorded the process resource use, so attempt 02 relies on that output instead.
