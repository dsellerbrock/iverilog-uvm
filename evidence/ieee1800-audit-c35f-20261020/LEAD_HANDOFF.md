# Clause 35 lead handoff

The lead's last saved assignment was to probe §§35.4, 35.8, and 35.9. Those
probes are complete; two additional §35.5.6.1 open-array element cases are
also recorded and need lead classification.

## Probe results

- **§35.4 / §35.5.4 candidate:** `../c35b-20261020/attempt-02-active-dup/RESULT.md`
  shows both `-g2017` and `-g2023` accept two called DPI imports with the same
  `c_identifier` and incompatible signatures, with no diagnostic. The
  standard text and the earlier open/closed search are in that attempt's
  `STANDARD.md` and `DEDUPE.md`.
- **§35.8/§35.9 tested subset:** the same result shows the context import and
  exported task advance to time 5; disable returns 1, the SV tail does not
  resume, and the imported-function path acknowledges the disabled state.
- **§35.5.6.1 candidates:** `../c35d-20261020/attempt-03-string-openarray/`
  and `attempt-04-struct-openarray/` show the compiler skips legal imported
  `string[]` and unpacked-structure-array calls with the same unsupported
  element diagnostic in both editions; the calls fail their `svSize` checks.
  Each attempt includes standard text and an open/closed dedupe. The existing
  1-D, dynamic 2-D, bounds, and packed-element open-array probes pass.

## Dedupe refresh

GitHub all-state searches for `c_identifier`, `DPI signature`, `duplicate
import`, `same c_identifier`, `35.4`, and `overloading DPI` returned no direct
Clause 35.4 issue. Searches for string/structure DPI arrays found broad
closed DPI history #13, generic open-array phase #45, different ABI issues
#505/#506, and ordinary SystemVerilog array issue #544; other matches (#19,
#27, #157, #666, #764) are unrelated. None covers these imported-array
element types.

## Current-main check

The probes used `cc25756d1`; current `origin/main` is `10f3a0a25`. The source
impact comparison is in `../c35b-20261020/CURRENT_MAIN_IMPACT.md`: changes
since the probe base are in constraint randomization, with no edits to the
DPI compiler, `vvp/vthread.cc`, or `vvp/vvp_dpi.cc`.

No issue was filed by the runner. Lead classification and filing remain
pending because `ask-techlead --agent A3 --lead 1800-audit` reports
`daily lead cap reached (160)` despite the supervisor's quota-refresh note.
