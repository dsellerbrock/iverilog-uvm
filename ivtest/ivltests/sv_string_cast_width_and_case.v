// A string converts to an integral value as its packed bytes, and a narrower
// target keeps the low bytes, exactly like a string literal (IEEE
// 1800-2017/2023 5.9, 6.16): logic[7:0]'("AB") is 8'h42. The conversion used
// to return the full string width, and a `case' on a string variable only
// matched because of that. The case expression now converts at the case
// context width (12.5).
module test;
  string s;
  int hit;
  typedef logic [7:0] b_t;
  typedef logic [63:0] w_t;
  task automatic pick(string k);
    case (k)
      "read":  hit = 1;
      "write": hit = 2;
      default: hit = 3;
    endcase
  endtask
  initial begin
    bit ok;
    ok = 1;
    pick("write"); ok &= (hit == 2);
    pick("read");  ok &= (hit == 1);
    pick("x");     ok &= (hit == 3);
    s = "AB";
    ok &= (b_t'(s) == 8'h42) && ($bits(b_t'(s)) == 8);
    s = "FIB";
    ok &= (w_t'(s) == 64'h464942);
    if (ok) $display("PASSED"); else $display("FAILED");
  end
endmodule
