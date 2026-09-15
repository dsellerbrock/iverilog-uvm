# Generated functions in constant evaluation

IEEE1800-2017 and2023 13.4.3 exclude functions declared inside generate blocks from constant functions. Previously an input-only generated function could silently fold a localparam.

The shared declaration classifier walks the callee ancestry up to its containing module/package. An intervening generate block marks the function nonconstant. Runtime calls retain normal lowering; required constant calls report the declaration scope before evaluation. The shared check covers ordinary and qualified call paths and cached classification.

[Focused evidence](2026-09-15_generated_constant_function_legality_validation.json) records direct, nested, generate-for and cached-call negatives with runtime generated functions and legal module/package constant/default controls in both editions. L96 neighbors pass. The separate default-argument assessment found no defect and prompted no source change. Broad batch qualification remains pending.
