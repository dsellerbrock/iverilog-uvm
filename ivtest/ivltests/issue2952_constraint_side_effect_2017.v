class side_effect;
  rand bit [3:0] a, b, c, d;
  rand bit [3:0] arr[1];
  constraint c1 { if (a == 0) ++a < 4; }
  constraint c2 { (b > 0) -> { b-- > 0; } }
  constraint c3 { c dist { (c += 1) := 1 }; }
  constraint c4 { foreach (arr[i]) (d = 2) == 2; }
endclass
module top;
  side_effect item;
  initial begin item = new; $display("rc=%0d", item.randomize()); end
endmodule
