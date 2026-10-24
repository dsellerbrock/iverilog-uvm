# IEEE 1800 §15.4 mailbox probes

The probe matrix and expected behaviors were supplied by the `1800-audit` tech lead. It covers mailbox construction, FIFO storage, `num`, blocking and try methods, `peek`, bounded blocking, wait ordering, message handles/strings, and parameterized mailboxes in IEEE 1800-2017 and 1800-2023. The negative compile cases check parameterized mailbox type enforcement; a runtime mismatch checks the required diagnostic.

Run `run-local.sh` through `~/codex-supervisor/localrun`. Each compile and simulation is limited to 20 seconds. Evidence includes exact toolchain hashes, stdout/stderr, and result codes.
