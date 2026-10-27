# Clause 32 issue dedupe

Before classification, captured all repository issues from GitHub: 275 open and 127 closed. Snapshots: [`open-issues.json`](open-issues.json), [`closed-issues.json`](closed-issues.json).

Searched issue titles and bodies case-insensitively for `SDF`, `specify`, `setup`, `setuphold`, `annotat`, `scale factor`, `scale type`, `mtm`, `delay path`, `pathpulse`, and `interconnect`.

Relevant open issues:

- [#880](https://github.com/dsellerbrock/iverilog-uvm/issues/880), §32.7: PATHPULSE values are not applied and the missing annotation warning is absent. It does not cover timing-check mapping, min/typ/max selection, scaling, or interconnect delays.
- [#890](https://github.com/dsellerbrock/iverilog-uvm/issues/890), §31.9: negative timing-check behavior, not SDF annotation mapping.
- [#891](https://github.com/dsellerbrock/iverilog-uvm/issues/891) and [#892](https://github.com/dsellerbrock/iverilog-uvm/issues/892), §31.4: `$timeskew`/`$fullskew` behavior, not SDF annotation mapping.

Relevant closed issue:

- [#436](https://github.com/dsellerbrock/iverilog-uvm/issues/436), §6: selected and generic operands in interconnect concatenations, not SDF interconnect delay annotation.

No open or closed issue found for §32.4 timing-check mapping, §32.4.4 SDF interconnect delay annotation, §32.9 `mtm_spec` selection, or §32.9 scale-factor behavior. Any new report still requires an observed failing probe and tech-lead confirmation.
