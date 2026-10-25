# §26.7 probe results

The standard text and probe scope are recorded in [STANDARD.md](STANDARD.md). All commands used the pinned main compiler `cc25756d187314742d347267c2a513b3e640a7fb`, with both `-g2017` and `-g2023`, and per-command 30-second timeouts. The tool hashes and raw output are preserved in [job 3554](remote-3554/), [job 3555](remote-3555/), and [job 3556](remote-3556/).

## Qualified built-in types

The full positive probe failed to compile in both editions at `std::semaphore`, `std::mailbox #(int)`, and `std::process`, with syntax/invalid-module-instantiation diagnostics. A reduced file with only those three qualified declarations also failed in both editions at all three declarations. The minimal reproducer is [`n26_07_std_qualified_types.sv`](../../../tests/1800_audit/c26/n26_07_std_qualified_types.sv). IEEE 1800-2017/2023 §26.7 Syntax 26-5 permits `std::` before a built-in data type identifier, and Annex G defines semaphore, mailbox, and process as built-in package classes. This is a confirmed conformance gap candidate.

The corresponding unqualified `semaphore`, `mailbox #(int)`, and `process` declarations compiled and ran in both editions, producing `I1 0`, `I2 6`, `I3 1`. The isolated `std::randomize(v)` call also passed both editions with `R1 1 3`; it is not a duplicate of the existing scope-randomize issues, which cover separate argument forms.

The user class named `semaphore` compiled and ran in both editions when isolated from the failing qualification, printing `S4 42`; the built-in type remains available through its unqualified imported spelling only in this probe. The full combination of local shadowing plus explicit `std::semaphore` cannot compile until the qualified-type gap is fixed.

## User declaration named `std`

`package std; endpackage` plus a top module compiled and ran in both editions, printing `STD_PACKAGE_DECLARED`. §26.7 says the built-in package cannot receive added declarations and describes its `std::` qualifier, but does not expressly prohibit a separate user package with the same spelling. This is recorded as an observation only; no issue is filed on that basis.

## Dedupe

Open and closed searches were saved under [`dedupe/`](dedupe/): `std package`, `std::`, `26.7`, `shadow semaphore`, `std::semaphore`, `std::mailbox`, and `qualified built-in type`. The `std::` results include unrelated scope-randomize reports (#621, #681, #682) and the separate weak-reference issue (#461); none covers qualified built-in class type declarations. Other hits (#12, #641, #27, and closed coverage issues) are also unrelated. No duplicate was found.

## 320-byte §21.7.3.4 boundary confirmation

The 320-byte rerun is recorded at [§21.7 attempt 03](../../ieee1800-audit-c21b-20261020/attempt-03-limit320/README.md). Both editions passed and produced identical 411-byte limited files: 337 bytes preceded the marker, and no value records followed it. No §21.7 issue was found.

## Job records

- Job 3554 completed the first harness but reported nonzero compile status for the full positive file in both editions; the runner's early `continue` skipped later cases. This was a compiler probe result, not infrastructure loss.
- Job 3555 completed the minimized package and boundary batch in 1 second, 1 CPU/1 GiB requested, exit 0. Individual compile/run statuses are preserved in raw files; the qualified-type declarations return compiler exit 4, while the implicit-import, `std::randomize`, `package std`, and limit cases pass.
- Job 3556 completed the isolated user-shadow probe in 1 second, 1 CPU/1 GiB requested, exit 0; both editions print `S4 42`.

No issue has yet been filed; the open/closed dedupe is complete and the reproduced candidate gap is ready for lead review.
