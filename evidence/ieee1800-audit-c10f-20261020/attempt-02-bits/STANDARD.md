# IEEE 1800 §20.6.2 reference

IEEE 1800-2017 §20.6.2, p. 599, says: “The $bits system function returns the number of bits required to hold an expression as a bit stream.” It gives an unpacked-structure example and says `$bits(MyType)` “shall return 9, the number of data bits needed by a variable of type MyType.” It also states that the result for fixed-size data types is determined at elaboration.

For this probe, `P` contains two fixed-size `int` members and therefore occupies 64 data bits. The packed structure, fixed-size unpacked array, typed pattern, and cast expression provide controls. IEEE 1800-2017 §6.24.3 defines bit-stream types as integral, packed, or string types; unpacked arrays, structures, or classes composed of those types; and dynamic arrays of those types. `real` is not in that list, so `$bits(real)` is not a valid positive case for §20.6.2 and its rejection is not counted as a conformance gap.
