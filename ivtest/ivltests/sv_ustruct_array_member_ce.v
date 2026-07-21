// Member access on an element of a static or plain dynamic array of an
// UNPACKED struct is not correctly lowered (the element's struct members
// are not addressed, so writes drop and reads return garbage). Rather than
// silently miscompiling, ivl now rejects it with a `sorry`. Queues,
// associative arrays, packed structs, and scalar unpacked structs are
// unaffected. (IEEE 1800-2017 7.2.1.)
module sv_ustruct_array_member_ce;
  typedef struct { int x; int y; } p_t;   // unpacked struct
  p_t pa[2];                                // static array of unpacked struct
  initial begin
    pa[0].x = 7;                            // must be diagnosed, not miscompiled
  end
endmodule
