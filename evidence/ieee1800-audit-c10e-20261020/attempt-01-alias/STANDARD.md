# IEEE 1800 §10.11 net-aliasing basis

- 1800-2017 §10.11, pp. 252–253; 1800-2023 §10.11, pp. 267–268: alias members must have the same size and type-compatible nets (the same net type); variables and hierarchical references are prohibited, and violating these rules is a fatal error.
- Both editions explicitly state that an individual signal may not alias itself and that a given alias may not be specified more than once.
- Both editions give the byte-swap example `alias {A[7:0],A[15:8],A[23:16],A[31:24]} = B;` with `A` and `B` as 32-bit inout wires. Repeated aliases are otherwise allowed when they add distinct connections, and their effects are cumulative.

Short governing text: “each member shall be the same size”; connected nets “shall be type compatible”; “Variables and hierarchical references cannot be used in alias statements”; “it is not allowed to specify an alias from an individual signal to itself or to specify a given alias more than once.”
