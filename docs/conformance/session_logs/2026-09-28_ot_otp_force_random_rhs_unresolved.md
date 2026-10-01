# OTP Control force RHS notices: unresolved

The pinned `hw/ip/otp_ctrl/dv/env/otp_ctrl_if.sv` (SHA-256
`ec53a9e4fa943fd4543b3176bdacb49dcec77fa472cf5eac98e37436179ab57f`)
expands `FORCE_OTP_PART_LOCK_WITH_RAND_NON_MUBI_VAL` ten times. Each expansion
forces four lock fields from separate `get_rand_mubi8_val(.t_weight(0),
.f_weight(0))` calls. The saved selected OTP compile exits zero but emits
exactly **40** `vvp.tgt sorry: procedural continuous assignments ... RHS ...
evaluated once` notices, one per call.

[The strict reducer](../repros/otp_force_rand_snapshot/repro.sv) and its
[runner](../repros/otp_force_rand_snapshot/run.sh) reproduce four notices per
macro expansion in both 2017 and 2023. Moving each draw to one persistent
signal removes the notices and preserves final values, but on a second call
without release, assigning that signal changes the **old** forced value before
the replacement `force` executes. An automatic task-local signal cannot be a
force RHS in Icarus. The runner checks eight draws, their order, held values
after task return, and the premature update in both editions.

No source patch or compiler warning suppression was applied. A safe repeated
call workaround would need separate persistent sources for active and next
forces across all 40 fields, which is too much state for this diagnostic-only
cleanup. No selected OTP compile or DV runtime was rerun for this assessment.
