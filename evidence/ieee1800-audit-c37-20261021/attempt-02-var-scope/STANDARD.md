# IEEE basis for the Clause 37 follow-up

Checked directly against IEEE 1800-2017 and IEEE 1800-2023. The relevant subclause numbering is unchanged.

## Instance relationships

IEEE 1800-2017 §37.10, details 2 and 3, states:

> 2) The vpiModule shall return a module if the object is inside a module instance, otherwise it shall return NULL.
>
> 3) The vpiInstance shall always return the immediate instance (package, module, interface, or program) in which the object is instantiated.

IEEE 1800-2023 §37.10, details 2 and 3, has the same text. Since `u` is instantiated inside `p37`, `vpiInstance` on `u` is expected to identify `p37`. The standard's VPI constant list labels `vpiScope` as the “containing scope object,” so that relation is also expected to identify `p37`. The `vpiModule` relation is probed separately; §37.10 detail 2 does not make clear whether applying it to a module-instance object means its own module or its containing module, so that result is recorded without assuming a parent expectation.

## Variables

The §37.12 Scope diagrams in both editions relate scopes to variables and identify `vpiVariables` as the one-to-many relation for variables. §37.17 Variables in both editions relates module/instance/scope objects to variables, and the variable model exposes `vpiSize`. Clause 38.23 says `vpi_iterate()` “shall ... traverse all objects of type type associated with object ref.” The probe compares an unused `logic [7:0] v`, the same declaration referenced by `$display`, and an unused `reg [7:0] v`.

The §37.12 Scope details about unnamed/named blocks and loop scopes do not define `vpiScope` behavior for a module instance. No separate norm is inferred for that relation from the diagram alone.

| Model | IEEE 1800-2017 | IEEE 1800-2023 |
|---|---|---|
| Instance | §37.10, p. 979 | §37.10, p. 1011 |
| Scope | §37.12, pp. 981–982 | §37.12, pp. 1013–1014 |
| Variables | §37.17, pp. 988–989 | §37.17, pp. 1025–1026 |
| `vpi_handle` / `vpi_iterate` | §§38.18, 38.23, pp. 1075, 1078 | §§38.18, 38.23, pp. 1111, 1114 |

The VPI constant list calls `vpiScope` “containing scope object” on IEEE 1800-2017 p. 1271 and IEEE 1800-2023 p. 1309.
