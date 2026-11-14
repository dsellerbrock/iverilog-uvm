module issue3296_unique_slice;
  class state_slice;
    rand bit [2:0] a;
    bit [2:0] t[8] = '{0, 1, 2, 3, 4, 5, 6, 7};
    constraint u { unique {a, t[0:3]}; }
  endclass
  class mixed_slice;
    rand bit [3:0] a, b;
    bit [3:0] t[4] = '{1, 2, 9, 9};
    constraint u { unique {a, b, t[0:1]}; }
  endclass
  class rand_slice;
    rand bit [3:0] a;
    rand bit [3:0] t[4];
    constraint u { t[0] == 1; t[1] == 2; t[2] == 9; t[3] == 9;
                   unique {a, t[0:1]}; }
  endclass
  class duplicate_slice;
    rand bit [3:0] a;
    bit [3:0] t[4] = '{1, 1, 2, 3};
    constraint u { unique {a, t[0:1]}; }
  endclass
  state_slice x = new;
  mixed_slice y = new;
  rand_slice z = new;
  duplicate_slice d = new;
  initial begin
    repeat (5) begin
      if (!x.randomize() || x.a < 4) $fatal(1, "state slice");
      if (!y.randomize() || y.a == y.b || y.a == 1 || y.a == 2 ||
          y.b == 1 || y.b == 2) $fatal(1, "mixed slice");
      if (!z.randomize() || z.a == 1 || z.a == 2) $fatal(1, "rand slice");
      if (d.randomize()) $fatal(1, "duplicate in slice");
    end
    $display("PASS");
  end
endmodule
