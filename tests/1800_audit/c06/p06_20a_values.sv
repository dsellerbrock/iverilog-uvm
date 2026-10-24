module sub #(parameter p = 3'h4, parameter [3:0] q = 4'h2);
  initial $display("SUB p_bits=%0d q_bits=%0d q=%0d", $bits(p), $bits(q), q);
endmodule
module subr #(parameter p = 3);
  initial $display("SUBR p=%f", p);
endmodule
module p06_20a #(int N = 5, M = N*16, type T = int, T x = 0);
  int pass = 0, fail = 0;
  task automatic ck(input string id, input bit c);
    if (c) pass++; else begin fail++; $display("FAIL %s", id); end
  endtask
  parameter msb = 7;
  parameter e = 25, f = 9;
  parameter r = 5.7;
  parameter byte_size = 8, byte_mask = byte_size - 1;
  parameter average_delay = (r + f) / 2;
  parameter signed [3:0] mux_selector = 0;
  parameter signed [3:0] SS = 4'hF;
  parameter real r1 = 3.5e17;
  parameter p1 = 13'h7e;
  parameter [31:0] dec_const = 1'b1;
  parameter newconst = 3'h4;
  parameter newconst2 = 4;
  parameter [3:0] UR = 4'hF;
  parameter pn = -3;
  parameter [15:0] PS = 16'hABCD;
  parameter logic [31:0] P1 [3:0] = '{1, 2, 3, 4};
  parameter r2 = $;
  sub #(.p(8'h55)) u1();
  sub #(.q(12'h123)) u2();
  subr #(.p(2.5)) u3();
  initial begin
    ck("dep", N == 5 && M == 80 && x == 0 && $bits(T) == 32);
    ck("literals", msb == 7 && e == 25 && f == 9 && byte_mask == 7);
    ck("real_param", r == 5.7 && r1 == 3.5e17 && average_delay > 7.34 && average_delay < 7.36);
    ck("p1_range", $bits(p1) == 13 && p1 == 13'h7e);
    ck("dec_const", $bits(dec_const) == 32 && dec_const == 1);
    ck("implied_range", $bits(newconst) == 3 && newconst == 4 && $bits(newconst2) >= 32);
    ck("signed_range", mux_selector == 0 && SS == -1);
    ck("range_unsigned", UR == 15 && !(UR < 0));
    ck("untyped_neg", pn < 0 && $bits(pn) >= 32);
    ck("part_select", PS[7:0] == 8'hCD && PS[15] == 1);
    ck("aggregate", P1[3] == 1 && P1[2][7:0] == 2 && P1[0] == 4);
    ck("unbounded", $isunbounded(r2) && !$isunbounded(N));
    $display("RESULT pass=%0d fail=%0d", pass, fail);
  end
endmodule
