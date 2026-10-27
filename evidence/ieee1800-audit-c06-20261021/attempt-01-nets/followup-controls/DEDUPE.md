# Open and closed issue dedupe: Clause 6.6 follow-up

The parent snapshot `../dedupe-all-issues.json` contains all 425 repository issues at query time: 298 open and 127 closed. The full textual matches are in `dedupe-search.txt`. Searches covered exact compiler text `non-array unpacked value cannot be driven onto a net`, plus `assignment pattern net`, `assignment pattern continuous assign`, `unpacked struct net`, `assignment pattern`, `continuous assignment`, `nettype`, `resolution function`, §10.3, and §10.9 across both open and closed issues.

Assignment-pattern matches are distinct from a continuous assignment pattern onto an unpacked-struct net:

- #857 (open, §10.9.2) concerns `default:` failing to descend into an unpacked-array member of an assignment-pattern struct.
- #539 (closed) concerns contextual sizing of a packed-struct assignment pattern member beside a wider sibling expression.
- #474 (closed) concerns keyed assignment-pattern initialization and reads of fixed-array parameters.
- #415 (closed) concerns nested assignment patterns in array-return values.
- #426 (open) concerns expression keys and remaining assignment-pattern key types.
- #818 (open) concerns unpacked-struct module ports rejected with an internal error; the probes here are non-port continuous assignments.
- No issue in the snapshot covers a continuous assignment pattern driving an unpacked-struct net or the matching internal error.

For user-defined nettypes, #435 (open) is specifically class-method resolution functions, and #897 (open) is distinct nettype matching on ports. Neither covers global-function resolution, nettype aliases, force/release, or rejection of multiple drivers on a nettype without a resolver. #878 covers unsupported `trireg`; #436 covers interconnect concatenation semantics, not the Clause 6.6.8 procedural/continuous-use prohibition.

The follow-up controls are not classified until Slurm job 3765 returns and the audit lead reviews the paired outcomes.
