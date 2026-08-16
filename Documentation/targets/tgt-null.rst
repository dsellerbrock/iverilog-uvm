
The null Code Generator (-tnull)
================================

The null target generates no code. Invoking it still runs preprocessing,
parsing, elaboration, semantic validation, and the normal netlist functors.
After those checks, the compiler omits construction of the duplicate target
API graph because the null target does not consume it. This makes ``-tnull``
appropriate for validating very large designs without paying for an unused
second representation of the design.
