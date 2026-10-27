# IEEE 1800 Clause 16.4 probes

The probes cover observed deferred assertion glitch suppression, stable
failure reporting, final deferred assert/cover actions, a module-level
deferred assertion item, passive user-task support in the Postponed region,
and rejection of a nonzero delay and a compound deferred action block. Both
IEEE 1800-2017 and 1800-2023 are tested.

IEEE 1800-2017/2023 §16.4 defines observed deferred `#0` and final deferred
assertions, requires pass/fail actions to be a single subroutine call or null,
and permits deferred assertion items outside procedures. Final deferred
actions execute in the Postponed region; observed deferred actions are
scheduled later in the current time step. Syntax 16-2 permits only `#0` or
`final`.

Slurm job **3173** used 1 CPU / 1 GiB and a 120-second timeout for every
compile and simulation. The pinned compiler is from staged source
`6604c23e197980b69a5b6b69864ff8ef8d05eba3` (Icarus 13.0-devel); `iverilog`
SHA-256 is `f8c0376ed73753c3327b1d7f5d4d647820836799064d965be7e1a8fbb9403ccd`
and `vvp` SHA-256 is
`53ad297f5370175e0df8af51c5947b7b34c723cf258617febf716cf82168249b`.

Both editions pass observed `#0` glitch suppression with a system-task action,
execute final assert/cover actions after the Active region and before the next
time step, execute a module-level deferred assertion item, and allow a passive
user task as a final-deferred action. Both editions reject a nonzero delay and
a compound action block with compile-time diagnostics. Per-edition logs and
the compiler version are in `results/` and `logs/`.

Input SHA-256:

| Probe | SHA-256 |
| --- | --- |
| `p16_04_observed_system_action.sv` | `6add0735819d260fc9f569402f2532eff6d5831436ecd301e3bcb89672cf78d8` |
| `p16_04_final_deferred.sv` | `15149808b0c19e759863d1f2825c9b63f08a02e4e8ebe5a9287696be2a1dfe71` |
| `p16_04_module_level_system_action.sv` | `5c276ddb1dfffa2ebe36000de6b8cf302d027d2d1f546fdfb2fa7466ecb3486e` |
| `p16_04_final_user_task_action.sv` | `7679142cfc102de596203f36f4f46a4633d94bb58085bec655051fa0936bff68` |
| `neg/n16_04_nonzero_delay.sv` | `2c766e0c9ed9ba77d895bba667a1b826d5012dd340cb334a66e26c7186999f20` |
| `neg/n16_04_block_action.sv` | `793c3cdbae248e28a5773f982be15ca44b656f0632311b8f15545b35528fe4e7` |
| `run.sbatch` | `666e2dc3569d5bf6a7a749a993a0004b3f4329da54c65579d16c595a3b8aba9f` |
