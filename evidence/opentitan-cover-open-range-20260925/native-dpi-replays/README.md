# Current-image PRESENT and PRINCE native DPI replays

These are named nonstandard compatibility smokes on the pinned OpenTitan
`a78922f14a8cc20c7ee569f322a04626f2ac6127` source. Both reuse the exact
`.vvp` outputs from the 84-row `-gcommercial-unsafe` matrix, with only their
required native reference libraries loaded by VVP `-d`. The current private
compiler `ivl` SHA-256 is
`9084fca0b6d1cbe00184583399ba1c5fcf0f10d78402f42c14fd50c3708dbdfe`;
VVP is `e54c7489ae51e3d14ba3b201cd4502b3d8ccfc7742926589cc9bddb82334bcae`.
The pinned checkout remained clean.

| Selected runtime identity | Original matrix row | Native DPI replay | Original checks |
| --- | --- | --- | --- |
| [PRESENT](present/result.json) | `RUNTIME_FAIL` (DPI symbols absent) | Exit 0, one `TEST PASSED CHECKS`, zero fail/error/assertion lines, `$finish` at 3,100,000 ps | Four golden and one random vector; each checks single/full round encryption/decryption against the C++ reference |
| [PRINCE](prince/result.json) | `RUNTIME_FAIL` (DPI symbols absent) | Exit 0, one `TEST PASSED CHECKS`, zero fail/error/assertion lines, `$finish` at 2,624,180 ps | Five golden and one random vector; checks old/new key schedules, registered/unregistered implementations, encryption/decryption against the C reference |

The testbench success text, `All encryption and decryption passes were
successful!`, appears once in each [PRESENT runtime log](present/runtime.log)
and [PRINCE runtime log](prince/runtime.log). The unchanged testbenches call
the failing DV status routine on any output mismatch before reaching that
text. `+smoke_test=1` keeps one random iteration after the golden vectors.

The two native libraries were built from FuseSoC-generated copies of the
pinned C/C++ sources and each exact compiler-generated `matrix-runtime.dpiexport.c`.
The [PRESENT](present/build_command.json) and [PRINCE](prince/build_command.json)
build command arrays, runtime command arrays, SHA-256 hashes, exit statuses,
and complete logs are in the linked row directories. No application or testbench
source was changed. The shared Icarus installation and Caliptra jobs were
untouched.

PRESENT compiled with six `uwire` multiple-driver compatibility warnings;
those semantics remain unqualified for IEEE conformance despite the checked
outputs. PRINCE compiled without semantic-debt diagnostics. These two replays
raise the selected checked nonstandard compatibility smoke count from 9/49 to
**11/49** when combined with the seven checked base-matrix DEBT rows and two
current-image OTP/CSRNG patched replays. The raw matrix remains 0/49
zero-debt passes, and the 35 UVM compile lane rows are separate.
