// A tranif network that does settle is unaffected by the settle limit.
module top;
  logic d = 0, en = 1;
  wire a, b;
  assign a = d;
  tranif1 g (a, b, en);
  initial begin
    #1 $display("on:  a=%b b=%b", a, b);
    en = 0; d = 1;
    #1 $display("off: a=%b b=%b", a, b);
    en = 1;
    #1 $display("on:  a=%b b=%b", a, b);
  end
endmodule
