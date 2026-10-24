# §16.13.5 cross-clock `matched` probe

IEEE 1800-2017 and IEEE 1800-2023 §§16.13.5–16.13.6 specify the named-sequence `.matched` method for synchronizing an endpoint from a source clock to the first subsequent destination-clock tick. A minimal legal cross-clock use fails to bind in both editions, while the existing same-clock `.matched` regression compiles and runs. This isolates the observed gap to the cross-clock use tested here.

- Host: DAN-DESKTOP; Slurm jobs 3584–3586. All completed with `ExitCode=0:0`, 1 CPU, 1 GiB, runtime 0–1 seconds.
- Source commit: `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`; pinned toolchain `/home/dsell/toolchains/iverilog-fb584a25-20261020`.
- Icarus/VVP SHA-256: `9760f8c1ab8ad03d64761b257db74ff07603a15c4d44d2bcdba75073f006911c` / `7fa3224c44e69b555fa86c1e3e048fa2709780276c6418ff8b7a7f0d63241c02`.
- Jobs 3584 and 3585 compile the cross-clock probe under `-g2017` and `-g2023`; both editions fail with `Unable to bind wire/reg/memory 'source_seq.matched' in 'main'`. The reduced attempt removes the unrelated cover-action warning from the first attempt. Runtime is therefore not reached.
- Job 3586 is a same-clock control using the existing `tests/sva_nfa/endpoint_triggered.sv`; both editions compile and run, printing the expected deliberate `EP_FAIL@55` and `endpoint_cover=2`.
- Issue dedupe used `gh issue list --state all` searches for `16.13.5`, `matched multiclock`, `matched`, and `sequence method`. Exact cross-clock searches returned no issue. #653 concerns `.triggered` in `wait` (§9.4.4); #719 concerns subroutine calls in sequence match items (§16.11); neither is the same behavior. Existing #446 may overlap because it covers multiclock handoffs/endpoints; the audit lead must decide whether to extend it or file a separate issue.
- No issue was filed or commented on. A lead-review draft is in `candidate-issue-draft.md`. Generated `.vvp` files and remote source copies were removed after evidence capture; logs, outputs, checksums and local probe sources remain.

The audit matrix remains `PROBED — LEAD PENDING` because the lead helper continues to report the daily cap reached despite the supervisor's refreshed-quota note.
