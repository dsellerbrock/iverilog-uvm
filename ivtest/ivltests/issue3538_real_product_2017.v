class positive_product_2017;
  rand real a;
  constraint c { a * 2.0 inside {[2.0:4.0]}; }
endclass

module test;
  positive_product_2017 p;
  initial begin
    p = new;
    if (!p.randomize()) $fatal(1);
  end
endmodule
