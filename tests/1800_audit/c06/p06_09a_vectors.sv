module p06_09a;
  int pass = 0, fail = 0;
  task automatic ck(input string id, input bit c);
    if (c) pass++; else begin fail++; $display("FAIL %s", id); end
  endtask
  logic [-1:4] b; logic signed [3:0] sg; logic [3:0] v4; logic [65535:0] big; bit [3:0] w4 = 4'hF;
  logic [4:0] x, y, z;  tri1 scalared [63:0] bus64;  tri vectored [31:0] data;
  initial begin
    ck("neg_range_bits", $bits(b) == 6);
    b = 6'b101010; ck("neg_range_idx", b[-1] == 1 && b[0] == 0 && b[1] == 1 && b[2] == 0 && b[3] == 1 && b[4] == 0);
    sg = 4'b1000; ck("signed_min", sg == -8);
    sg = 4'b0111; ck("signed_max", sg == 7);
    v4 = 4'b1010; ck("msb_first", v4[3] == 1 && v4[2] == 0 && v4[1] == 1 && v4[0] == 0);
    big = '1; ck("vector_65536", $bits(big) == 65536 && big[65535] && big[0]);
    w4 = w4 + 1; ck("mod_arith", w4 == 0);
    v4 = 4'b0001; v4 = v4 - 2; ck("mod_arith_neg", v4 == 4'hF);
    ck("scalared_vectored_decl", $bits(bus64) == 64 && $bits(data) == 32);
    ck("multi_decl", $bits(x) == 5 && $bits(y) == 5 && $bits(z) == 5);
    $display("RESULT pass=%0d fail=%0d", pass, fail);
  end
endmodule
