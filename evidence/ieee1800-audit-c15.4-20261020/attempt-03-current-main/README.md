# Current-main rerun for issue #695

Re-runs the already-filed §15.4.6/.8 mailbox type-mismatch reproducer against
the pinned `cc25756d1` compiler under both editions. The test source is the
existing [`p15_04_mailbox_dynamic_type.sv`](../../../tests/1800_audit/c15/p15_04_mailbox_dynamic_type.sv).

- Standard basis: [`STANDARD.md`](STANDARD.md)
- Harness: [`run.sbatch`](run.sbatch)
- Result: [`RESULT.md`](RESULT.md)
