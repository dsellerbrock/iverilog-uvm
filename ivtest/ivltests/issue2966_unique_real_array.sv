class item;
  real a[2];
  rand bit x;
  constraint c { unique {a}; }
endclass
module top;
  item o;
  initial begin
    o = new;
    $display("%0d", o.randomize());
  end
endmodule
