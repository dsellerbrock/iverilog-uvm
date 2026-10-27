# IEEE 1800 §20.6.2 reference

IEEE 1800-2017 §20.6.2, p. 599: “The $bits system function returns the number of bits required to hold an expression as a bit stream.” For an unpacked structure `MyType`, the clause states `$bits(MyType)` “shall return 9, the number of data bits needed by a variable of type MyType.” It says the result for fixed-size data types is determined at elaboration.

IEEE 1800-2017 §6.24.3 defines bit-stream types as integral, packed, or string types, plus unpacked arrays/structures/classes and dynamic arrays composed of those types. The probe tests fixed-size unpacked structures, packed controls, an unpacked fixed array, a typed pattern, and a cast of an unpacked-structure variable. `$bits(real)` was removed because `real` is not a bit-stream type.
