# Result — current-main rerun of issue #695

The existing §15.4.6/.8 reproducer compiled with exit code 0 and ran with
exit code 1 under both `-g2017` and `-g2023` on Slurm job 3567. The tested
toolchain is pinned at `cc25756d1`; binary hashes are preserved with the raw
logs under [`remote-3567/`](remote-3567/).

Both editions produced the same failing behavior:

```text
try_peek(int): result=1 num=1
try_get(int): result=1 num=0
```

`try_peek(int)` returns positive 1 instead of a negative type-mismatch value.
`try_get(int)` also returns positive 1 and consumes the queued string, so the
following matching-string operations fail. This confirms the already-open
issue #695 against the current pinned main build. IEEE 1800-2017 and
1800-2023 §§15.4.6 and 15.4.8 require a negative return on type mismatch.
