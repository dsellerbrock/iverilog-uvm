// Net aliases (IEEE 1800-2017/2023 23.3.1): `alias a = b = c;' makes whole nets
// and net part selects one net, including through tri-state resolution. The
// `alias' module item was a syntax error.
module main;
  wire [3:0] a, b, c;
  wire [7:0] big;
  wire [3:0] lo, hi;
  tri [3:0] bus1, bus2;
  logic en = 0;
  alias a = b = c;
  assign c = 4'd9;
  alias big[3:0] = lo;
  alias big[7:4] = hi;
  assign big = 8'hA5;
  alias bus1 = bus2;
  assign bus1 = en ? 4'd3 : 4'bzzzz;
  assign bus2 = en ? 4'bzzzz : 4'd12;
  int errors;
  initial begin
    #1;
    if (a !== 4'd9 || b !== 4'd9) begin $display("FAIL chain a=%b b=%b", a, b); errors++; end
    if (lo !== 4'h5 || hi !== 4'hA) begin $display("FAIL parts lo=%h hi=%h", lo, hi); errors++; end
    if (bus1 !== 4'd12 || bus2 !== 4'd12) begin $display("FAIL bus %b %b", bus1, bus2); errors++; end
    en = 1; #1;
    if (bus1 !== 4'd3 || bus2 !== 4'd3) begin $display("FAIL bus en %b %b", bus1, bus2); errors++; end
    if (errors == 0) $display("PASS");
  end
endmodule
