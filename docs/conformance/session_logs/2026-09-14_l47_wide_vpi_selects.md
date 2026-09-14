# L47 — Wide indexed part-selects through VPI

The one-dimensional formatting reducer returned `0101` instead of `xxxx` for
an eight-bit signal selected at 2^32. Ordinary expression and formatting paths
were inconsistent. The compiler now uses width-preserving constant normalization
and portable 64-bit part-select descriptors. VPI constant bases retain 64 bits;
dynamic bases use the shared arbitrary-width converter already used by packed
and queue slice evaluation. Out-of-range reads return X and writes do nothing.

A monitor reproducer exposed callback code slicing the parent string with an
invalid offset. Callbacks now compare values obtained from the selected VPI
handle. This preserves partial-select X padding and avoids callbacks caused
solely by changes outside the selected bits. Direct tests verify wide reads,
wide no-write, partial writes with neighbor preservation, and callback counts.

Focused legacy 3/3, JSON 6/6 and direct VPI checks in both editions pass. Null and
synthesis checks pass both editions, and the L46 JSON neighbor passes 2/2.
Logs are in `evidence/dynamic-mixed-driver-assessment/final-l47-*`, plus
`l47-vpi-2017.log` and `l46-neighbor.log`. Root reviewed descriptor transport,
constant/dynamic base conversion, value/write paths and callbacks. An unused
local was removed during final review; this does not change execution.

IEEE 1800-2017/2023 11.5.1 governs select values. Figure 37-2 describes VPI range
tags as handle relations; the legacy integer property extension is clamped
without overflowing but is not claimed as full range-handle support. Complete
metadata and callbacks triggered only by index changes remain unqualified.

This is the fifth focused feature. Full suites remain deferred until the
approximately ten-feature checkpoint. No application or full-clause pass is
inferred from these results. DD-022 prefix and write bounds remain open.
