// M10-3: chandle + real + string context ABI round-trips
module top;
  import "DPI-C" function chandle mk_h(input int v);
  import "DPI-C" function int     rd_h(input chandle h);
  import "DPI-C" function void    fr_h(input chandle h);
  import "DPI-C" function real    rmul(input real a, input real b);
  import "DPI-C" function string  scat(input string a, input string b);
  initial begin
    chandle h; int ok = 1; real r; string s;
    h = mk_h(21);
    if (h == null) begin $display("FAIL chandle null"); ok = 0; end
    if (rd_h(h) != 21) begin $display("FAIL chandle roundtrip rd=%0d", rd_h(h)); ok = 0; end
    fr_h(h);
    r = rmul(2.5, 4.0);
    if (r != 10.0) begin $display("FAIL real ABI r=%0f", r); ok = 0; end
    s = scat("ab", "cd");
    if (s != "abcd") begin $display("FAIL string ABI s=%s", s); ok = 0; end
    if (ok) $display("PASS m10_3");
    $finish(0);
  end
endmodule
