# IEEE 1800 external constraint blocks and inheritance

- Standards checked directly in the PDFs: IEEE 1800-2017 §§18.5.1–18.5.2, pp.510–511; IEEE 1800-2023 §§18.5.1–18.5.2, pp.529–531.
- Positive probe covers implicit/explicit prototypes, external blocks, empty implicit prototype, inherited constraints, name-based replacement, inherited pure constraint implementation, and virtual `randomize()` dispatch through a base handle.
- Six negative probes cover missing explicit block, duplicate external blocks, duplicate in-class prototype/block, pure constraint in non-virtual class, missing pure implementation, and same-name pure constraint plus block.
- Each source is tested under both editions. Per-process compile/runtime timeout is 30 seconds; negative cases compile only. Inputs, process-group timeout helper and run script hashes are in `input/SHA256SUMS-input.txt`.
- Open+closed issue searches are recorded in `dedupe-open-closed.txt`.
