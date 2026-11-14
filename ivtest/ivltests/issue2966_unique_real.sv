class item;
  real a = 1.0, b = 2.0;
  rand bit x;
  constraint c { unique {a, b}; }
endclass
module top;
  item o;
  initial begin
    o = new;
    if (!o.randomize()) $fatal(1, "distinct real members rejected");
    o.b = 1.0;
    if (o.randomize()) $fatal(1, "equal real members accepted");
    $display("PASS real uniqueness");
  end
endmodule
