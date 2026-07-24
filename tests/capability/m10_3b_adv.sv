// M10-3 adversarial: chandle/real/string in output+inout position,
// chandle stored in class/array, real inout, string output.
module top;
  import "DPI-C" function void mk_out(input int v, output chandle h);
  import "DPI-C" function void bump_io(inout int v);
  import "DPI-C" function void rbump(inout real r);
  import "DPI-C" function void sout(output string s);
  import "DPI-C" function int  rd_h(input chandle h);
  class Holder; chandle h; endclass
  initial begin
    chandle a, arr[2]; int ok = 1; int iv = 5; real rv = 1.5; string sv;
    Holder hh = new;
    mk_out(7, a);
    if (rd_h(a) != 7) begin $display("FAIL output chandle rd=%0d", rd_h(a)); ok = 0; end
    hh.h = a;
    if (rd_h(hh.h) != 7) begin $display("FAIL chandle in class"); ok = 0; end
    arr[1] = a;
    if (rd_h(arr[1]) != 7) begin $display("FAIL chandle in array"); ok = 0; end
    bump_io(iv);
    if (iv != 6) begin $display("FAIL inout int iv=%0d", iv); ok = 0; end
    rbump(rv);
    if (rv != 2.5) begin $display("FAIL inout real rv=%0f", rv); ok = 0; end
    sout(sv);
    if (sv != "hi") begin $display("FAIL output string sv=%s", sv); ok = 0; end
    if (ok) $display("PASS m10_3b");
    $finish(0);
  end
endmodule
