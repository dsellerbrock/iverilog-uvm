# Open and closed issue dedupe: §16.18 and clocking-input assertion sampling

Fetched every repository issue before the probes with `gh issue list --state all --limit 1000`; the retained [`dedupe-all-issues.json`](dedupe-all-issues.json) contains 422 issues: 295 open and 127 closed. Searched titles and bodies in both states for §16.18, clockvar/concurrent assertion, clocking-block-variable assertion, input skew, and `#1step`.

No existing issue covers §16.18's assertion sampling rule or rejection of non-`#1step` sampling for clocking-block inputs. Near matches are separate:

- #711 (open) covers use of clocking-block inputs in sampled-value functions such as `$past(cb.d)` (§16.9.3), not direct concurrent-assertion sampling or invalid input skews.
- #917 (open) covers property/sequence declarations inside a clocking block failing to parse; it explains why standard examples a2/a4 cannot be tested, but does not cover a1/a3 equivalence or input skew validation.
- #679 (closed) covers default clocking for sampled-value functions in procedural event controls.
- #17 (closed) is a broad clocking-block project milestone without these specific semantics.
- #906 (open) is virtual-interface cycle-delayed clockvar driver code generation, not assertion sampling.

The 422-issue snapshot predates the #919 and #920 filings, so it correctly records 295 open and 127 closed issues at search time. The lead used it to confirm no duplicate: #919 covers the §16.18 clockvar lag, while #920 groups the same missing error for both `#3` and `#0` skews. Neither overlaps #711's sampled-value-function behavior or #917's declaration grammar gap.
