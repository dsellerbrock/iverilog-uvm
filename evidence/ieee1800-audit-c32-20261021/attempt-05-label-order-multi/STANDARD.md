# Clause 32 basis for the remaining probes

The clause text is materially the same in IEEE 1800-2017 and IEEE 1800-2023.

| Clause | Required behavior and citation |
| --- | --- |
| §32.3 | The SDF annotator must warn for data it cannot annotate (2017 p. 892; 2023 p. 924). |
| §32.4 | A CELL may contain DELAY, TIMINGCHECK, and LABEL sections; LABEL introduces specparam values (2017 p. 892; 2023 p. 924). |
| §32.4.3 | LABEL annotations update specparams; expressions containing them are reevaluated (2017 pp. 895–896; 2023 pp. 927–928). The standard example uses `(dhigh 60)`, so the probe's `(tr 4)` form is exact. |
| §32.5 | SDF constructs apply in file order; a later INCREMENT modifies an earlier value and ABSOLUTE overwrites it, including across unlike constructs (2017 p. 897; 2023 p. 929). |
| §32.6 | Separate `$sdf_annotate` calls may modify or overwrite earlier files; a scope argument selects different design regions (2017 p. 898; 2023 p. 930). |
| §32.9 | The optional `module_instance` argument establishes the hierarchy level from which annotation runs (2017 p. 900; 2023 p. 932). Each scoped SDF probe uses an empty CELL INSTANCE; the simulator's scope resolver maps that form to the passed scope. |

The §32.4.3 wording is: “The SDF LABEL construct annotates to specparams. Any expression containing one or more specparams is reevaluated when annotated to from an SDF file.” The later example applies LABEL to a specparam in a specify path expression.
