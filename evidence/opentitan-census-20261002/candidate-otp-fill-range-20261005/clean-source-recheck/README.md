# Clean pinned OTP recheck

With the candidate compiler's fill-range fix, clean pinned OpenTitan
`lowrisc:dv:otp_ctrl_sim:0.1` no longer reports the unbased-fill endpoint
error. The row remains `FAIL`: 15 procedural-force warnings are classified as
hard diagnostics, and 36 covergroup constructor purity warnings remain debt.
The [result JSON](result.json), [summary](result.md),
[compile log](compile.log), and [guard log](guard.log) preserve this
post-fix result. The matrix input was clean commit
`a78922f14a8cc20c7ee569f322a04626f2ac6127`.
