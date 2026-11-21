class state_real_unique;
  real a[2];
  rand bit value;
  constraint distinct { unique {a[0:1]}; }
endclass

module test;
  state_real_unique item;
  initial begin
    item = new;
    if (!item.randomize()) $finish;
  end
endmodule
