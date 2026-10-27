# Clause 6.6 follow-up controls

Follow-up controls for the initial Clause 6.6.7 results. These separate continuous assignment patterns on unpacked-struct nets from user-defined nettype resolution, aliasing, force/release, and the unresolved-nettype multiple-driver rule. Cases U1b-U4b use typed variables with declaration assignment patterns as drivers. P1-P3 remove user-defined nettypes and vary the assignment-pattern target form.

Run every source independently with -g2017 and -g2023 on pinned Icarus cc25756d1. Expected U1b/U2b: 3.5; U3b: resolved 3.5, forced 9.0, released 3.5; U4b: only the unresolved-nettype multiple-driver diagnostic; P1-P3: 1 3.
