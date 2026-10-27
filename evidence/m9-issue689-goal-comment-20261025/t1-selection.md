# #689 T1 selection

Graphify query: “Which existing ivtest tests exercise SystemVerilog covergroup option goal, comment, weight, at_least reads and writes, per-instance or inherited covergroup options, and what simulator paths do they cover?” It surfaced `sv_covergroup_option_scope`, `sv_covergroup_procedural_item_options`, `sv_covergroup_four_state_options`, and the `sv_covergroup_class_inheritance*` tests.

The implementation touches covergroup metadata, elaboration, and expression/lvalue path rewriting. T1 therefore selects every `sv_covergroup*` row from both legacy and JSON manifests, including the new paired 2017/2023 tests, the extension case, and the existing unsupported-member negative.
