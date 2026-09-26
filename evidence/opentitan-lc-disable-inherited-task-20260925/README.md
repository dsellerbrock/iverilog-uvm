# OpenTitan LC_CTRL: disable of an inherited task (2026-09-25)

Qualification: nonstandard compatibility (`-gcommercial-unsafe`, the
matrix's flag for every compile). Compile-only replay; LC_CTRL remains 0/1
released DV.

`lc_ctrl_smoke_vseq.sv:34-35` executes `disable run_clk_byp_rsp;` and
`disable run_flash_rma_rsp;`, tasks declared in a base sequence class.
IEEE 1800-2017/2023 9.6.2 resolves the disabled name by ordinary scope
resolution, which from a class method includes inherited methods. Icarus
searched only lexical scopes and failed with "Cannot find scope".

Replay of the unchanged matrix command on the pinned OpenTitan tree
(`a78922f14a8cc20c7ee569f322a04626f2ac6127`, clean): hard error sites fall
from 4 to 2 (`lc-ctrl-compile.log`); both `disable` sites are gone. The two
remaining sites (`tokens_a`, `process.self`) are fixed on separate branches.

Gates on the private build (`tool_hashes.txt`): legacy ivtest 6694 total,
6689 passed, 0 failed (2 not implemented, 3 expected fail); JSON/VVP
3747/0; real-DPI UVM 358 passed, 0 failed, 0 skipped. Paired 2017/2023
`sv_disable_inherited_task` covers an inherited task and a derived
override; a gold-checked negative keeps unknown names and inherited
functions loud.
