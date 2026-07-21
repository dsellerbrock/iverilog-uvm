// Whole-element assignment to an element of a static (fixed-size) unpacked
// array of an UNPACKED struct is not correctly lowered: the array is stored
// as an array of objects, but the element write degrades the struct r-value
// to a null store, so the element ends up null and later reads (and %p)
// abort in the runtime. A whole-array pattern assignment (arr = '{...}')
// works, and dynamic/associative arrays and queues of unpacked structs
// assign elements correctly, so only this static-array per-element case is
// rejected. Rather than silently miscompiling, ivl now rejects it with a
// `sorry`. This is the whole-element sibling of the member-access diagnostic
// exercised by sv_ustruct_array_member_ce. (IEEE 1800-2017 7.2.1.)
module sv_ustruct_array_element_ce;
  typedef struct { int a; int b; } p_t;   // unpacked struct
  p_t pa[2];                                // static array of unpacked struct
  initial begin
    pa[0] = '{a:1, b:2};                    // must be diagnosed, not miscompiled
  end
endmodule
