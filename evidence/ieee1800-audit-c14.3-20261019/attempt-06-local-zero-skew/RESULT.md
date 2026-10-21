# Attempt 06 — local zero-skew runtime check (not a semantic result)

The saved Slurm bytecode was run with `/opt/homebrew/bin/vvp` under `localrun`. It could not execute: its embedded system VPI paths point to the deleted Slurm install, and the Homebrew stable runtime reports a VVP syntax error. The follow-up attempt to recompile with Homebrew Icarus stopped immediately because that distribution supports through IEEE 1800-2012 and rejects `-g2017`.

No output from this attempt is counted as a probe result. The source-level evidence remains Slurm job 3152; it compiled the 2017 `#0` output-skew case but did not run it, and the 2023 case passed compile/run. IEEE 1800-2017/2023 §14.4 explicitly permits `#0` output skew.
