# Open and closed issue dedupe — uninstantiated generate hierarchy reference

The same fresh GitHub snapshot as [the `$unit::` dedupe](DEDUPE.md) contains 436 issues (309 open, 127 closed). Search covered titles and bodies in both states; raw JSON is `dedupe-all-issues.json`.

## Searches

| Search term | Hits |
| --- | --- |
| `uninstantiated`, `uninstantiated generate` | 0 |
| `hierarchical generate`, `hierarchical block`, `generate block hierarchy` | 0 |
| `top.g.v`, `reference to uninstantiated generate`, `nonexistent hierarchical` | 0 |
| `hierarchical reference` | Open #921, #906, #812, #761, #758, #611; none covers a variable reference into an uninstantiated generate block |
| `generate hierarchy` | Closed #500 only |
| `hierarchical name` | Open #930 and #823; separate defparam and modport task-export rules |

## Related issue requiring lead judgment

Closed [#500](https://github.com/dsellerbrock/iverilog-uvm/issues/500) is titled “§23.7.1 — Diagnose unresolved unindexed hierarchical task calls.” Its acceptance text mentions missing members on unindexed module/generate hierarchy, but its reproducer and implementation scope are specifically task calls. The new reproducer is a variable reference to a block omitted by `if (0)`: compilation succeeds with a warning and simulation prints `32` in both editions; the matching `if (1)` control prints `7`. The lead must decide whether #500 covers this broader hierarchical-variable failure (then comment there) or whether it merits a separate §23.9/§27.5 issue. A3 has not filed or commented.
