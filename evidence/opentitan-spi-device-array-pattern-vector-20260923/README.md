# OpenTitan SPI Device array-pattern vector-context reducer

`reducer.sv` combines the two failing source forms from the pinned SPI Device compile: unpacked-array membership (`inside {READ_CMD_LIST}`) and assignment of an unpacked-array concatenation to a queue (`target_ops = {READ_CMD_LIST}`). With the local prebuilt compiler, both `-g2017` and `-g2023` report `this expression (kind 26) cannot be evaluated in a vector context` at lines 8 and 9.

Kind 26 is `IVL_EX_ARRAY_PATTERN` (`ivl_target.h`). The fallback that emits this diagnostic is `tgt-vvp/eval_vec4.c`; it also emits a zero fallback and fails code generation. The source-level semantics differ: 1800-2017 §11.4.13 traverses elements of unpacked arrays in an `inside` set; §10.10 permits unpacked-array concatenations as assignment-like sources for fixed arrays, queues, and dynamic arrays. Queue update behavior is also described in §7.10.4.

The exact census log has six `inside` sites and two queue-array-concatenation sites. The reducer is intentionally not a proposed complete qualification of either source form.
