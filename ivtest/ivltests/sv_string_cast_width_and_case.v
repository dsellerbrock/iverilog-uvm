// A string converts to an integral value as its packed bytes, and a narrower
// target keeps the low bytes, exactly like a string literal (IEEE
// 1800-2017/2023 5.9, 6.16): logic[7:0]'("AB") is 8'h42. String case
// comparisons must retain the selector's full contents (12.5).
module test;
  string s;
  int hit;
  typedef logic [7:0] b_t;
  typedef logic [63:0] w_t;
  task automatic pick(string k);
    case (k)
      "read":  hit = 1;
      "write": hit = 2;
      "AB":    hit = 4;
      "":      hit = 5;
      default: hit = 3;
    endcase
  endtask
  task automatic pick_unique(string k);
    unique case (k)
      "write": hit = 2;
      default: hit = 3;
    endcase
  endtask
  function automatic int const_pick(string k);
    case (k)
      "write": const_pick = 2;
      "AB": const_pick = 4;
      "": const_pick = 5;
      default: const_pick = 3;
    endcase
  endfunction
  localparam int CONST_EQUAL = const_pick("write");
  localparam int CONST_LONGER = const_pick("xwrite");
  localparam int CONST_ZERO_BYTE = const_pick("A\000B");
  localparam int CONST_EMPTY = const_pick("");
  initial begin
    bit ok;
    ok = 1;
    pick("write"); ok &= (hit == 2);
    pick("read");  ok &= (hit == 1);
    pick("xwrite"); ok &= (hit == 3);
    pick("x");     ok &= (hit == 3);
    pick_unique("write"); ok &= (hit == 2);
    pick_unique("xwrite"); ok &= (hit == 3);
    ok &= (CONST_EQUAL == 2) && (CONST_LONGER == 3);
    ok &= (CONST_ZERO_BYTE == 4) && (CONST_EMPTY == 5);
    s = "A\000B";
    pick(s); ok &= (hit == 4) && (s.len() == 2);
    s = "";
    pick(s); ok &= (hit == 5) && (s.len() == 0);
    s = "AB";
    ok &= (b_t'(s) == 8'h42) && ($bits(b_t'(s)) == 8);
    s = "FIB";
    ok &= (w_t'(s) == 64'h464942);
    if (ok) $display("PASSED"); else $display("FAILED");
  end
endmodule
