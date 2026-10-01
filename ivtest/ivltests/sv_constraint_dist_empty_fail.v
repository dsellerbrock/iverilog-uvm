// A distribution requires at least one item; empty braces must fail at parse.
module test;
endmodule
class empty_dist_item;
  rand bit value;
  constraint c { value dist {}; }
endclass
