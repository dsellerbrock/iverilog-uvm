# Initial paired-edition probe result

Slurm job 3558 compiled, linked, and ran the legal alias, exported-task timing,
and both §35.9 disable paths successfully under `-g2017` and `-g2023`. Both
outputs were byte-identical:

```text
A1 9
T1 5
T2 1 16
F1 1
```

The negative test source at this stage declared two incompatible imports with
the same `c_identifier`, but did not call them. Compilation returned 0 in both
editions, so the harness exited 1 because its expected rejection was absent.
That was not sufficient to distinguish lazy validation from a conformance
gap. The active-call follow-up in
[`attempt-02-active-dup`](../attempt-02-active-dup/RESULT.md) is the
reproduction used for the §35.4 finding.
