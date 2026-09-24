# Caliptra checker source-copy diagnostic (2026-09-24)

The pinned `caliptra_top_sva.sv` is unchanged at SHA-256
`6bd2ade137a90c0701aab28951ba6f8918724e0467c21756b0c308e6e9081c89`.
The frozen [patch](../../docs/conformance/release_overlays/caliptra/l0_pure_checker_functions.patch)
deletes nine internal `$display` calls from the KV debug and MLDSA private-key,
public-key, and signature helper functions. It changes no comparison, return,
property expression, disable guard, or outer assertion failure action. A
zero-fuzz dry run and application to a disposable one-file copy produce SHA-256
`6e67d67966b030931ec222aacfd0863086c7d35b5e916acd5f358a90ed538654`.
The first-mismatch detail formerly printed inside each helper is deliberately
lost; a real failed property still emits its unchanged outer failure action.
This is a source-copy diagnostic overlay, not an IEEE conformance result or a
pass on pristine released Caliptra.

The [paired control](pure_checker_controls.sv) exercises a vacuous mismatch,
true pass, true failure, reset-disabled mismatch, and a true failure whose
live value changes by NBA in the same clock slot. In both 2017 and 2023,
the pure and print-bearing forms have identical failure actions: `OUTER live`
and `OUTER nba` once each; vacuous, pass, and disabled cases produce none.
The print-bearing form produces 18 eager `INNER` lines, while the pure form
produces zero. All four compile/run combinations pass with exit zero; exact
commands and tool hashes are in [results.json](results.json). The `INNER`
count includes calls made before the implication or disable gate takes effect;
it is not an assertion-failure count.

The runner's explicit `--checker-source-overlay` option copies and patches
only this pinned checker file under `/tmp`, substitutes that file in a copied
compile profile, checks source/patch/result hashes, and retains the normal
zero-error, pass-marker, firmware-execution, DPI, and original assertion-action
requirements. Combining it with `--reset-overlay` additionally uses a
hash-guarded copy of the bundled Caliptra BFM. These two diagnostic profiles
have separate qualification labels and denominators. Other display-bearing
assertion helpers remain unchanged and may require case-specific review.
