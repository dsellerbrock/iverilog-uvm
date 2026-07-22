// Member access on an element of a plain DYNAMIC array of an UNPACKED
// struct is not yet correctly lowered (the darray's object elements are not
// default-constructed, so a member write to a fresh element would drop).
// Rather than silently miscompiling, ivl rejects it with a `sorry`. A
// STATIC (fixed-size) unpacked array now works (its elements are lazily
// default-constructed at run time); queues, associative arrays, packed
// structs, and scalar unpacked structs are unaffected too.
// (IEEE 1800-2017 7.2.1.)
module sv_ustruct_array_member_ce;
  typedef struct { int x; int y; } p_t;   // unpacked struct
  p_t da[];                                 // DYNAMIC array of unpacked struct
  initial begin
    da = new[2];
    da[0].x = 7;                            // must be diagnosed, not miscompiled
  end
endmodule
