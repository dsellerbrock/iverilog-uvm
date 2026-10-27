module p06_24a;
  int pass = 0, fail = 0;
  task automatic ck(input string id, input bit c);
    if (c) pass++; else begin fail++; $display("FAIL %s", id); end
  endtask
  typedef logic [3:0] l4_t;
  typedef enum {red, green, blue, yellow, white, black} Colors;
  parameter P = 16;
  logic [7:0] regA;  logic signed [7:0] regS;  shortint si;  byte by;
  int x = 5;  l4_t lv = 4'b1x0z;  logic [31:0] r32;
  initial begin
    regA = unsigned'(-4);        ck("unsigned_neg", regA == 8'b11111100);
    regS = signed'(4'b1100);     ck("signed_4bit", regS == -4);
    ck("int_real_expr", int'(2.0 * 3.0) == 6);
    si = shortint'({8'hFA, 8'hCE}); ck("shortint_concat", si == 16'shFACE);
    ck("real_round", int'(3.7) == 4 && int'(-3.7) == -4 && int'(3.4) == 3);
    by = byte'(300);             ck("byte_trunc", by == 44);
    r32 = 17'(x - 2);            ck("size_cast_val", r32 == 3 && $bits(17'(x - 2)) == 17);
    ck("size_cast_param", $bits((P + 1)'(x - 2)) == 17);
    ck("size_cast_trunc", 4'(8'hAB) == 4'hB);
    ck("size_cast_unsigned_ext", 16'(8'hff) == 16'h00ff);
    ck("size_cast_signed_ext", 16'(8'shff) == 16'shffff);
    ck("4state_preserved", l4_t'(lv) === 4'b1x0z);
    ck("signed_pass", signed'(8'hff) == -1 && $bits(signed'(8'hff)) == 8);
    ck("unsigned_pass", unsigned'(8'shff) == 255);
    ck("enum_nocheck", int'(Colors'(10)) == 10);
    ck("enum_static", Colors'(2 + 3) == black);
    ck("cast_equiv_assign", int'(by) == 44);
    $display("RESULT pass=%0d fail=%0d", pass, fail);
  end
endmodule
