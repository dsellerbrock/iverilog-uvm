# Local build setup attempt

The first localrun stopped before compiling because the source archive has no generated `configure` script until `autoconf` runs. No tests ran. Peak RSS was about 2.4 MiB. The next attempt stages a clean source copy, runs autoconf, and configures out of tree.
