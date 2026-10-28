# Array equality order evidence

IEEE 1800-2017 §7.4.3 lists equality operations on arrays and frames its examples around matching shape and type. IEEE 1800-2023 §7.4.6 gives the corresponding array operations. IEEE 1800-2017/2023 §6.22.2(d) defines fixed unpacked-array type equivalence recursively by element-type equivalence and each array dimension's size; declared range bounds may differ. IEEE 1800-2017/2023 §11.4.5 describes equality as bitwise comparison.

Those clauses do not directly state how equality pairs elements when equivalent arrays use different bounds. IEEE 1800-2017/2023 §7.6 states for array assignment that corresponding elements are paired in left-to-right array order. The probe uses that same positional pairing as an inference for equality; it does not attribute the pairing rule directly to §7.4.3 or §11.4.5.

The probe distinguishes declaration-order pairing from numeric-index pairing, checks direction changes independently in each dimension, checks size-one dimensions, and rejects same-total-count arrays with different shapes. Expected output is recorded alongside the compiler output in `output.txt`.
