# IEEE 1800 §18.8 probe plan

Standards read from the local 1800-2017 §18.8 (pp. 532–533) and 1800-2023 §18.8 (pp. 554–555). Both editions require random variables to begin active; inactive rand/randc variables behave as state variables; setters can address an object, one variable, an unpacked-array element or whole array, and an unpacked-structure member or whole structure; object-handle mode does not propagate to child variables; an absent or non-rand property is a compile error; query form is singular; the built-in cannot be overridden; static rand-mode state is shared. 2017 spells the setter as a task and 2023 as a void function; the probes use statement-call syntax common to both editions.

## Probes

- `tests/1800_audit/c18/p18_08_modes.sv`: initial active state for rand/randc, selected and all-variable setters, disabled state-variable behavior during randomization, object-handle non-propagation, selected and whole fixed-array modes, and static sharing.
- `tests/1800_audit/c18/neg/n18_08_rand_mode_override.sv`: rejection of a user-defined override of the built-in method.
- Existing regression probes: `sv_rand_mode_nested_class_property`, `sv_rand_mode_static_inheritance_specialization`, `sv_rand_mode_fixed_indexing`, `sv_rand_mode_dynamic_indexing`, `sv_rand_mode_invalid_field_fail`, `sv_rand_mode_dynamic_whole_query_fail`, `sv_struct_array_rand_mode`, and `sv_struct_array_rand_mode_query_fail`.

Runtime results use the batch 5 staged compiler. An unsuccessful `iverilog` compile is evidence only when its diagnostic matches the feature under test; unrelated parser errors do not count.

## Run plan

- Candidate: batch 5 staged commit `4bfe7d04ca190adc9ad74268445bf42a6f187f59` from Slurm T2 job 2714.
- Probe job 2716 is queued with `afterany:2714`; it uses one CPU and 2 GiB, and runs both editions after the full batch gate releases the allocation.
- Latest input SHA-256 (attempt 3): `p18_08_modes.sv` `f61d4c47baee2f3b5d1527aec37c8dd40818213a1c9421c8e584f1be49be5b34`; `p18_08_struct_mode.sv` `2df8aa7e7bc79966cea23e75bd239fd47b6ce65ae2f5dac9da17ae19a4e71f26`; `n18_08_rand_mode_override.sv` `a4165c1eeeb41e7da519b15943c8dbbade90546cb2d06de5cc16f0645449a198`. Earlier inputs are preserved with their attempt results.

The probes confirm a partial §18.8 result: the whole-unpacked-structure setter leaves member variables active in both editions. The lead verified the identical 2017/2023 wording (pp. 533/555) and filed the gap as [#675](https://github.com/dsellerbrock/iverilog-uvm/issues/675).

Attempt 1 (Slurm job 2716) compiled the combined probe with the candidate in `-g2017`, then failed at its whole-structure setter assertion. The full batch gate passed 4,774 JSON tests, 367 UVM tests, and the UVM front-end scenarios; the targeted whole-structure behavior is not covered by that pass. Attempt 1 output and script are preserved under `attempt-01/`. The probe is being reduced into separate core and struct cases before assigning a language-conformance result.


## Results

- Staged compiler commit: `4bfe7d04ca190adc9ad74268445bf42a6f187f59`; `iverilog` SHA-256 `a13ca89f4d858c9534c75971aa96a450461c1cd6ddddaf2d1cfd10b6f3c0e0a4`; `vvp` SHA-256 `9674cc9900874cee228cce17ea69b616cf21ae9920389acf54dd81571866eab8`.
- Job 2716: the initial combined probe failed at its whole-structure setter assertion; preserved under `attempt-01/`.
- Job 2731: the split core probe passed in both `-g2017` and `-g2023`; the whole-structure test failed in both; a user declaration overriding `rand_mode` was rejected in both with the built-in-method diagnostic. Results are under `attempt-02/`.
- Job 2732: the reduced direct whole-structure setter probe still failed in both editions (`rand_mode(0)` left at least one rand member active). Results are under `attempt-03/`.
- Existing related legacy regressions in T2 job 2714 passed: nested-class property, static mode sharing/specialization, fixed and dynamic array selection, struct-member element selection, invalid/non-rand property rejection, and whole-array query rejection. Their raw logs are in `rand-mode-legacy-logs.tar.gz` (SHA-256 `6bbc474459792cebb721d88521917e228e6beebd476466993c5709e154c022c5`).
- T2 job 2714 passed: legacy `7530/7530` with 2 not implemented and 3 expected failures, JSON `4774/4774`, bundled VPI `133/133`, negative suite `152/152`, UVM `367/367`, both VIF focus gates, and the UVM front end. Batch Fast Linux passed; three hosted Windows lanes remain pending.
