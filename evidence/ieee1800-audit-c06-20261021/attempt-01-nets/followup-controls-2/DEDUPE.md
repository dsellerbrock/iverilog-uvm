# Open/closed issue dedupe — Clause 6.6 follow-up controls 2

Snapshot taken 2026-10-21 with `gh issue list --state all --limit 1000`:
425 issues total (298 open, 127 closed). Targeted `gh issue list --state all`
searches produced:

| Search | Matches |
|---|---|
| `unpacked struct net` | #819 open (two-state net type accepted); #818 open (unpacked-struct module ports rejected) |
| `continuous assignment unpacked struct` | None |
| `nettype resolution function real` | None |
| `nettype force release` | None |
| `nettype alias` | #897 open (distinct user-defined nettypes on ports) |
| `"unsupported return type"` | None |

A scan of all 425 issue titles/bodies also found #435 (class-method resolver
support), #818 (ports), #819 (two-state net types), #857 (nested structure
assignment-pattern defaults), and #897 (nettype port matching). These are
nearby but have distinct stated scopes. #818 is the candidate overlap for
C1: its reproducer is a module port, whereas C1 declares a local wire; compare
the corrected C1 result before deciding whether to scope-comment it or file a
new issue. Corrected C1 rejects at the local `wire` declaration with
`Net n can not be of type <no_type>` in both editions. #818 reports the same
type rejection for a port plus an additional synthesis error; whether the
root cause is shared remains for the lead to decide. The resolver and
force/release searches found no existing issue with the tested
package-function real resolver or force/release scope.

The audit lead classified C1 as the same root cause as #818 and filed #922
(§6.5/§10.3) and #923 (§6.6.7) after reviewing the probe and this open/closed
search. I posted the C1 scope-extension comment on [#818](https://github.com/dsellerbrock/iverilog-uvm/issues/818#issuecomment-6319412119).
After filing, a fresh count is 427 issues total (300 open,127 closed), with
274 open issues labeled `1800-audit`. The targeted search results above are
the pre-filing snapshot used for dedupe.
