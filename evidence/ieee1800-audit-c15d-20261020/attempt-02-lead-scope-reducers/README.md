# Lead-directed §15.5.3 scope reducers

Two compile-only cases requested by the lead: the event-typed formal alone and an ordinary task formal called from a fork. Run under both `-g2017` and `-g2023`, each compiler process limited to 20 seconds. Combined in one Slurm job with the selected §18.5.14 probe. Raw results and hashes will be copied here after completion.

## Result

The event-typed formal alone fails with compile rc 2 under both editions; a normal `input int` task call inside a fork compiles in both. This isolates #829 to the standard event formal, not fork invocation. See `RESULT.md`.
