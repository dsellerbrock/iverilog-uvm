# Open and closed issue dedupe — 2026-10-21

Queried all 409 issues in `dsellerbrock/iverilog-uvm` (gh issue list --state all --limit 1000) before proposing any new issue. Search terms: `default clocking`, `instantiated module`, `clockvar`, `synchronous drive`, `intra-assignment delay`, `cycle delay`, `global clocking`, `$global_clock`, `14.12`, `14.14`, `14.16`, and `gclk`.

## Potential overlaps reviewed

| Issue | State | Existing scope | Why it does not duplicate these probes |
|---|---|---|---|
| #17 | Closed | Broad clocking/program-block implementation; explicitly lists default and global clocking out of scope | Umbrella history, no §14.12 scope or §14.16 restriction result |
| #44 | Closed | Parser sorry cleanup, including global-clocking syntax | Syntax-only acceptance work; does not cover elaborated $global_clock resolution or synchronous-drive behavior |
| #679 | Closed | §16.9.3 sampled-value functions in procedural event controls with default clocking | Different use of default clocking |
| #712 | Open | §16.9.4 global-clock past/future sampled-value functions | Does not test the $global_clock event or its hierarchical lookup |
| #437 | Closed | §14 runtime-selected clocking-block output drives | Fixed runtime-selected target behavior; K3 is cycle-delayed virtual-interface drive code generation |
| #674 | Open | §14.16.2 unpacked net clockvar outputs | K8 uses a scalar net and passes; not cycle-delayed drive or write restrictions |
| #438 | Closed | §14 fixed-unpacked variable clockvar outputs | Fixed-unpacked variable target, separate from these scalar targets |
| #705 / #704 | Open | §14.11 expression-valued cycle delays and pre-event ##0 | Not a cycle delay on a synchronous-drive RHS |
| #702 | Open | §14.5 rejecting non-lvalue expressions assigned to clocking outputs | Different assignment validation |
| #701 | Open | §14.3 rejecting reads from output clockvars | Not a write restriction |
| #686 | Open | §19.7 duplicate covergroup option specification | Unrelated; checked because the lead requested the number |

The broad query also returned #811, #717, #710, #40 and #18; these concern module port connections or SVA sequence/sample semantics and are unrelated. A second open-and-closed search for nonblocking property assignment, clockvar cycle, synchronous-drive cycle_delay, default-clock scope, clockvar writes, and VVP target diagnostics found #705/#704 (already distinguished above) and #538 (unpacked-array equality flag limit; unrelated). No matching issue for a cycle-delayed synchronous drive, instantiated-module default-clock scope, or blocking/intra-assignment-delay clockvar writes was found.

## Probe outcomes needing lead classification

- K3 vif.cb.data <= ##2 value: VVP code generation rejects it in both editions with “this nonblocking property assignment form is not yet supported without changing its NBA semantics”. The direct top.bus.cb rerun compiles and runs in both editions (AFTER at t=5 ns; drive at t=25 ns), isolating the gap to the virtual-interface form.
- N2: a child module with no local default clocking accepts ##1 even though only the parent declares a default clocking.
- N3/N4: blocking assignment to a clockvar and regular intra-assignment delay in a clockvar drive both compile without diagnostic.
- N5 (continuous assignment to the clockvar), N1 (duplicate default clocking), and N6 (duplicate global clocking) are rejected.

The distinct candidate mechanisms are K3 virtual-interface cycle-delayed clockvar drive, N2 default-clock scope, and N3/N4 write-form restrictions. No issue was filed by the runner.
