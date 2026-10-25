# IEEE 1800 §§8.19–8.20 constant properties and virtual override matching

This lead-selected probe covers the standard's `Jumbo_Packet` example, an
instance constant assigned in its constructor, covariant virtual-function
return types, and default expressions that differ while remaining present on
both declarations. Nine negative files check the specified constant-property
and override-signature restrictions. `r08_19_const_double_assignment.sv` is
record-only: §8.19 says assignment can occur only once in the constructor but
does not explicitly require a compile-time error for a second assignment.

Standard references: IEEE 1800-2017/2023 §8.19 and §8.20. Section 8.19 says an
instance constant can be assigned at runtime only once in its class
constructor and cannot be static. Section 8.20 requires matching override
argument types, names, qualifiers, and directions; a return type must match or
be derived; default expressions may differ, but default presence must match.

Expected positive output in both editions:

```text
K1 9216 5
K2 3 4
V6 ok
V7 2
```

Run the positive and every negative under `-g2017` and `-g2023`, with a
30-second process-group timeout. The record-only C5 probe is compiled and run
when accepted. Dedupe and lead classification will follow in `RESULT.md`.

## Archive integrity

- `results-3501.tar.gz`: 7951 bytes; SHA-256 `db905d52342b59fe4b669328c7f2825fac9216cb53afdcefde2ee278ddcb5370`.
