# Standard rules exercised — IEEE 1800-2017 and IEEE 1800-2023

Both editions were checked directly. The relevant numbering is the same in both editions. One distinction matters: **§39.4.1** covers assertion-system callbacks registered through `vpi_register_cb`; `vpi_register_assertion_cb` is specified in **§39.4.2**.

Annex M in both editions assigns `vpiAssertion` the integer value **744** and `vpiAssertionDisable` the value **620**. The current Icarus `sv_vpi_user.h` instead defines `vpiAssertion` as **686** and does not define `vpiAssertionDisable`. The probe reports both the header value and the result of iterating with Annex M's literal 744; it supplies standard value 620 as a fallback solely to test the control operation. This header/API discrepancy is evidence for lead classification, not yet an issue claim.

- **§39.3.1, obtaining assertion handles:** “Iterate all assertions in the design: use a NULL reference handle (ref) to `vpi_iterate()`.” The test uses `vpi_iterate(vpiAssertion, NULL)`, scans the result, and prints each full name.
- **§39.4.2, assertion callbacks:** the callback receives its reason, callback time, assertion handle, attempt-related information, and the registration's user data. `cbAssertionFailure` reports an attempt/property failing to reach success; `cbAssertionSuccess` reports an attempt/property reaching a success state. This probe counts both reason codes. The failure callback's attempt information includes `attemptStartTime` and `detail.failExpr`; the success callback's valid attempt field is `attemptStartTime`.
- **§39.5.2, assertion control:** the second argument to assertion controls must be a valid assertion statement handle. `vpiAssertionDisable` prevents new attempts for that assertion without affecting existing attempts. The disable variant calls `vpi_control(vpiAssertionDisable, pa)` before any clock edge.

The main design's positive and negative samples are nonoverlapping: it fails at 5 and 15 ns, sets `a` at 20 ns, then succeeds at 25 and 35 ns. The disable variant uses the same stimulus, but disables the assertion at time 0.
