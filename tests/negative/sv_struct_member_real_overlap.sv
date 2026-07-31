// The other half of sv_struct_member_mixed_assign: making the mixed
// continuous/procedural check bit-accurate must NOT weaken it. The SAME
// member driven both ways is a genuine IEEE 1800-2017 6.5 conflict and
// must still be rejected.
module sv_struct_member_real_overlap;
  typedef struct packed { logic [1:0] a; logic [1:0] b; } s_t;
  s_t s;
  logic [1:0] x = 2'b01;
  assign s.a = 2'b10;
  always_comb s.a = x;      // same bits, both ways -- illegal
endmodule
