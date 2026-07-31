// A conditional whose two arms are WHOLE unpacked arrays, with a
// compile-time constant condition (IEEE 1800-2017 7.6 array assignment,
// 11.4.11 conditional). OpenTitan's aes_cipher_core writes exactly this:
//
//     key_full_d = !CiphOpFwdOnly ? key_dec_q : prd_clearing_key_i;
//
// with the condition a module parameter.
//
// Three separate things had to line up, and each failed on its own:
//
//  1. A bare unpacked-array identifier could not elaborate against an
//     unpacked-array context type. NetNet::net_type() reports only the
//     ELEMENT type for an unpacked signal -- the dimensions live on
//     array_type() -- so the comparison never matched.
//  2. The same mismatch rejected the arm again at the implicit-cast
//     check in elaborate_rval_expr.
//  3. With those fixed, PAssign's whole-array copy recognizes its
//     source by PExpr SHAPE (it resolves the name itself, there being
//     no whole-array r-value to elaborate first), so a conditional hid
//     the array from it. The assignment fell through to the vector path
//     and the code generator ABORTED on
//     `lwid == ivl_signal_width(lsig)'.
//
// Both polarities are instantiated and every element is checked, so a
// fix that folded to the wrong arm -- or copied the right arm into the
// wrong slot -- still fails here.
module sv_uarray_const_ternary;

  localparam int N = 3;

  logic [31:0] p [N];
  logic [31:0] q [N];
  logic [1:0][15:0] r0, r1;
  int errors = 0;

  sub #(.Fwd(1'b0)) u_a (.o(p), .m(r0));   // !Fwd = 1 -> takes `a'
  sub #(.Fwd(1'b1)) u_b (.o(q), .m(r1));   // !Fwd = 0 -> takes `b'

  task ck(input string t, input [31:0] got, input [31:0] exp);
    if (got !== exp) begin
      $display("FAIL %0s: got %h expected %h", t, got, exp);
      errors = errors + 1;
    end
  endtask

  initial begin
    #1;
    // every element of the selected array, both polarities
    ck("a0", p[0], 32'hAAAA_0000);
    ck("a1", p[1], 32'hAAAA_0001);
    ck("a2", p[2], 32'hAAAA_0002);
    ck("b0", q[0], 32'hBBBB_0000);
    ck("b1", q[1], 32'hBBBB_0001);
    ck("b2", q[2], 32'hBBBB_0002);
    // a packed-element array through the same shape
    ck("m_a", {16'b0, r0[1]}, 32'h0000_A11A);
    ck("m_b", {16'b0, r1[1]}, 32'h0000_B11B);

    if (errors == 0) $display("PASSED");
    else $display("FAILED with %0d errors", errors);
  end

endmodule

module sub #(parameter bit Fwd = 1'b0)
            (output logic [31:0] o [3], output logic [1:0][15:0] m);

  logic [31:0] a [3];
  logic [31:0] b [3];
  logic [31:0] d [3];

  logic [1:0][15:0] ma, mb, md [1];
  logic [1:0][15:0] mdst [1];

  always_comb begin
    a[0] = 32'hAAAA_0000; a[1] = 32'hAAAA_0001; a[2] = 32'hAAAA_0002;
    b[0] = 32'hBBBB_0000; b[1] = 32'hBBBB_0001; b[2] = 32'hBBBB_0002;
  end

  // the construct under test
  always_comb d = !Fwd ? a : b;

  assign o = d;

  // same shape, packed element type
  logic [1:0][15:0] pa [1];
  logic [1:0][15:0] pb [1];
  always_comb begin
    pa[0] = {16'hA11A, 16'hA00A};
    pb[0] = {16'hB11B, 16'hB00B};
  end
  always_comb mdst = !Fwd ? pa : pb;
  assign m = mdst[0];

endmodule
