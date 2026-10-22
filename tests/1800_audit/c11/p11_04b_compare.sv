module p11_04b;
  int pass = 0, fail = 0;
  task automatic ck(input string id, input bit c);
    if (c) pass++; else begin fail++; $display("FAIL %s", id); end
  endtask
  class K; endclass
  logic signed [3:0] s4 = -1;  logic [3:0] u4 = 4'hF;  logic signed [7:0] s8 = -1;
  int b = 5, a = 2, alpha = 237, beta = 0, cnt = 0;  real r1 = 2.5;  K k1, k2;
  function logic sc(); cnt++; return 1; endfunction
  initial begin
    ck("rel_signed", s4 < 0 && !(s4 < 4'd1));
    ck("rel_unsigned", u4 > 4'd1);
    ck("rel_real", r1 > 2 && r1 < 3);
    ck("rel_x", $isunknown(4'b1x00 < 4'd2) && !$isunknown(1 < 2));
    ck("rel_precedence", (b - (1 < a)) == 4 && (b - 1 < a) == 0);
    ck("eq_ext_signed", s4 == s8);
    ck("eq_ext_unsigned", u4 == 8'h0F);
    ck("eq_x", $isunknown(4'b1x00 == 4'b1x00) && (4'b1x00 === 4'b1x00));
    ck("caseeq_xz", !(4'b1x00 === 4'b1z00) && (4'b1x00 !== 4'b1z00));
    ck("eq_known_mismatch", (4'b1x00 == 4'b0x00) === 1'b0);
    ck("eq_real", 2.5 == 2.5 && 3 == 3.0);
    k1 = null;  ck("handle_null", k1 == null && !(k1 != null) && k1 === null);
    k2 = new; k1 = k2;  ck("handle_eq", k1 == k2 && k1 != null);
    ck("wild_basic", (4'b1011 ==? 4'b10x1) === 1'b1 && (4'b1011 !=? 4'b10x1) === 1'b0 && (4'b1111 ==? 4'b10x1) === 1'b0);
    ck("wild_left_x", (4'b10x1 ==? 4'b1011) === 1'bx && (4'b10x1 ==? 4'b10x1) === 1'b1);
    ck("wild_z", (4'b1001 ==? 4'b10z1) === 1'b1);
    ck("wild_ext", (8'b0000_1011 ==? 4'b10x1) === 1'b1);
    ck("logical", (alpha && beta) == 0 && (alpha || beta) == 1 && (!alpha) == 0 && (!beta) == 1);
    ck("implication", (0 -> 0) == 1 && (1 -> 0) == 0 && (1 -> 1) == 1 && (0 -> 1) == 1);
    ck("equivalence", (1 <-> 1) == 1 && (1 <-> 0) == 0 && (0 <-> 0) == 1);
    ck("logical_x", ((1'bx && 1'b1) === 1'bx) && ((1'bx && 1'b0) === 1'b0) && ((1'bx || 1'b1) === 1'b1) && ((!1'bx) === 1'bx));
    cnt = 0; a = (sc() <-> sc());  ck("equivalence_once", cnt == 2);
    ck("logic_precedence", (0 && 1 || 1) == 1);
    $display("RESULT pass=%0d fail=%0d", pass, fail);
  end
endmodule
