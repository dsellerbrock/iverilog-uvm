# Attempt 02 result — partial probe, one probe-source error

Slurm job 3497 ran on DAN-DESKTOP with 1 CPU, 1 GiB, and a 15-minute limit.
Compiler: Icarus 13.0-devel at source `cc25756d1`; `iverilog` SHA256
`1088dd266d4715d5a99d4eb5f7ae7a128449744927bae1971b37278872613593`, `vvp`
SHA256 `e66837952db8927f4ef69007b4290c07e23f30f9258facae416da98c95715bbb`.
Raw logs and per-case records are in `results-3497.tar.gz`.

The positive probe did not compile in either edition because this Icarus syntax
does not accept `handle = new ClassName`; the source has been corrected to
construct through a typed handle in attempt 03. These two failures are probe
errors, not simulator evidence.

The four §8.21 negative probes produced identical results in both editions:

- Direct construction of an abstract class: rejected with “Can not create
  object of virtual class”.
- Pure virtual method declared in a non-virtual class: rejected with the
  appropriate diagnostic.
- Non-virtual subclass omitting the inherited pure method and then constructed:
  **accepted** (compile rc 0). Attempt 03 also invokes the method to record
  runtime behavior before lead classification.
- Pure virtual method with a body: rejected at parse time.

This is a candidate §8.21 conformance gap only; no issue has been filed. The
open-and-closed searches are recorded in `dedupe-open-closed.txt`; they found
no direct abstract-class issue. Closed #455 is specifically the 2023
`:initial`/`:extends`/`:final` override-specifier feature and is not the
missing-pure-implementation behavior.
