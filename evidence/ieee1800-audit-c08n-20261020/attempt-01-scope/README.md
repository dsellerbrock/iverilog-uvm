# IEEE 1800 §§8.23–8.25.1 class scope, out-of-block methods, parameterized classes

Probe selected by the 1800-audit lead. It covers class static members and
enumerators through `::`, nested class types, extern method bodies (including
an in-class typedef used as an out-of-block return type), the IEEE 1800-2023
parameterized-class static-method example, and two invalid forms.

Standard references: IEEE 1800-2017 §§8.23–8.25.1 and §8.24; IEEE
1800-2023 §§8.24–8.25.1. Section 8.24 requires an out-of-block declaration to
match its prototype exactly, with specified exceptions. Section 8.25.1 makes
unadorned `C::` illegal for a parameterized class outside its class or
out-of-block scope and permits explicit specializations such as `C#()::`.

Sources:

- `tests/1800_audit/c08/p08_23_25.sv`
- `tests/1800_audit/c08/neg/n08_25_param_class_scope_unadorned.sv`
- `tests/1800_audit/c08/neg/n08_24_extern_signature_mismatch.sv`

Expected positive output in both editions:

```text
SC1 2
SC2 1
SC3 7
OB1 2 9
OB2 4
PC1 2 10
```

The Slurm harness compiles and runs the positive source and expects both
negative sources to fail compilation, with 30-second process-group timeouts.
Open-and-closed issue dedupe and lead classification will be recorded after
the run.
