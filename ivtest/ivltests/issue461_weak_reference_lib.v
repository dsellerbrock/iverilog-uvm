// IEEE 1800-2023 8.30: weak_reference is known in a library module (-y)
// that is parsed during elaboration, when no earlier source named it.
module top;
   issue461_libmod u ();
endmodule
