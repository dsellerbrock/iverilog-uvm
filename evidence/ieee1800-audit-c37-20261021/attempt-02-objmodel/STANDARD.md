# Clause 37 object-model requirements

The relevant relationship diagrams have the same subclause numbering in IEEE 1800-2017 and IEEE 1800-2023. The parameter diagram moved from §37.26 in 2017 to §37.28 in 2023.

- **Module and instance:** §37.5 (Module) diagrams top modules and nested module instances; its detail 1 states that top-level modules are accessed with `vpi_iterate()` and a NULL reference. §37.10 (Instance) connects an instance to its module, parameters, and child objects; the instance model exposes `vpiDefName` and `vpiName`.
- **I/O declarations and ports:** §37.13 (I/O declaration) connects a module to I/O declarations and exposes `vpiDirection` and `vpiSize`. §37.14 (Ports) relates a module's ports to port objects. The probe's `input logic a` and `output logic [3:0] y` therefore should report directions `vpiInput`/`vpiOutput` and sizes 1/4.
- **Nets:** §37.16 (Nets) relates module nets and port instances. The probe does not claim net-model coverage beyond the port observations above.
- **Variables:** §37.17 (Variables) connects a module's `vpiVariables` relation to variable objects and exposes `vpiSize`; `logic [7:0] v` should report size 8.
- **Value parameter:** §37.26 (2017) / §37.28 (2023) connects module `vpiParameter` objects to parameter values. Detail 1 in both editions requires `vpi_get_value()` to return the value parameter's value at the end of elaboration; `P` should be 7.

Edition/page references checked directly in the PDFs:

| Model | IEEE 1800-2017 | IEEE 1800-2023 |
|---|---|---|
| Module / instance | §§37.5, 37.10, pp. 976, 979 | §§37.5, 37.10, pp. 1008, 1011 |
| I/O declaration / ports | §§37.13, 37.14, pp. 983–984 | §§37.13, 37.14, pp. 1015–1016 |
| Nets / variables | §§37.16, 37.17, pp. 987–988 | §§37.16, 37.17, pp. 1019, 1025 |
| Parameter | §37.26, p. 1005 | §37.28, p. 1038 |
