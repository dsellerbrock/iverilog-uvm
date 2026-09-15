# Constant mixed equality — L104

FOCUSED_TESTED under IEEE 1800-2017 and 1800-2023 5.9,11.4.5,11.4.6,Table11-21 and11.8.2. Required broad batch gates remain pending.

A constant function comparing an integer holding97 with packed literal `"a"` previously failed evaluation despite its runtime equivalent returning true. Case and wildcard equality also assumed already-equal operand widths. The shared equality folders now apply maximum operand width and common signedness before comparing unequal-width integral values. True string equality retains raw string comparison, distinguished by the original operand expression types; string-literal markers alone do not imply string-variable semantics.

Paired constant/runtime checks cover operand order, signed and unsigned extension, X/Z, logical/case/wildcard equality, different-width and NUL-prefixed packed literals, and true string variables. An illegal class/string comparison retains its diagnostic. The change is confined to eval_tree.cc; relational operators and broader expression semantics are not newly qualified.

[Revision-scoped validation](2026-09-15_constant_mixed_equality_validation.json) records the exact installed candidate, focused and neighbor results. Local baseline, failed initial harness setup and corrected direct runs remain under `evidence/batch-20260915-after-l95`.
