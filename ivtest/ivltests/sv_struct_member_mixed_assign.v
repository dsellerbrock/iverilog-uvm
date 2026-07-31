// IEEE 1800-2017 6.5 forbids mixing continuous and procedural
// assignment to the same VARIABLE. 7.2.1 stores a packed structure
// without gaps, so a member IS a part select of the containing vector
// -- the conflict must be judged over the BITS actually written.
//
// The packed-struct-member l-value path tested the whole signal
// instead, so two spellings of the SAME bits disagreed:
//     assign s.a;    always_comb s[1:0] = x;   // accepted
//     assign s[3:2]; always_comb s.b   = x;    // rejected
// and driving disjoint members of one control register from different
// sources -- ordinary RTL, and what OpenTitan's aes/hmac/otbn do --
// was rejected outright.
//
// This checks BOTH directions: disjoint members must be accepted AND
// compute correctly, while a genuine same-member overlap must still be
// an error (pinned separately in tests/negative).
module sv_struct_member_mixed_assign;
  typedef struct packed {
    logic [1:0] mo;
    logic [1:0] sl;
    logic [1:0] md;
    logic [1:0] op;
  } ctrl_t;

  ctrl_t ctrl;
  logic [1:0] c_src = 2'b10;
  logic [1:0] p_src = 2'b01;

  // continuous on two members, procedural on the other two
  assign ctrl.sl = c_src;
  assign ctrl.mo = c_src;
  always_comb ctrl.op = p_src;
  always_comb ctrl.md = p_src;

  initial begin
    #1;
    if (ctrl.mo === 2'b10 && ctrl.sl === 2'b10 &&
        ctrl.md === 2'b01 && ctrl.op === 2'b01)
      $display("PASSED");
    else
      $display("FAILED mo=%b sl=%b md=%b op=%b", ctrl.mo, ctrl.sl, ctrl.md, ctrl.op);
  end
endmodule
