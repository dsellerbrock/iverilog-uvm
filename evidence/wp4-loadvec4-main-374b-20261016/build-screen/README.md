# Fused converter focused instruction screen

Pinned measurement base: `374b037e7c8fba7097e0b86b05be7956ca6b5487`.

The 100,000-access `converter_wide_index` workload ran under Callgrind on
separate reference and candidate builds from the same base. The candidate
uses the fused word-plane X/Z, extraction, and overflow scan.

| Result | Reference | Candidate | Change |
| --- | ---: | ---: | ---: |
| Whole-process instructions | 2,342,064,005 | 1,861,103,335 | −20.535761% |

The runner output and stderr were byte-identical. The wide-index edge fixture
also printed identical `PASSED` output on both builds, covering wide signed
and unsigned indices, saturation, 65-bit tail words, and X/Z. The focused
result clears the 10% instruction gate; the 18-workload broad regression
screen is still running.

Job 1620 used Valgrind 3.26.0 on CPU 3. Raw Callgrind profiles, per-side build
logs, input hashes, source/submodule provenance, and outputs are retained in
this directory. The candidate patch hash is in `results/provenance.sha256`.
