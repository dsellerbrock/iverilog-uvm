class assign_range_dist;
  rand int x;
  constraint c { x > 101; x dist {[100:102] := 1, 103 := 1}; }
endclass

class divide_range_dist;
  rand bit [7:0] x;
  constraint c { x > 100; x dist {[100:101] :/ 1, 102 := 1}; }
endclass

module sv_dist_range_excluded_weight;
  assign_range_dist a;
  divide_range_dist d;
  int a_range, a_scalar, d_range, d_scalar;

  initial begin
    a = new();
    d = new();
    repeat (1500) begin
      if (!a.randomize()) $fatal(1, "assign range randomize failed");
      if (a.x == 102) a_range++;
      else if (a.x == 103) a_scalar++;
      else $fatal(1, "unexpected assign range value %0d", a.x);

      if (!d.randomize()) $fatal(1, "divide range randomize failed");
      if (d.x == 101) d_range++;
      else if (d.x == 102) d_scalar++;
      else $fatal(1, "unexpected divide range value %0d", d.x);
    end

`ifdef EXPECT_2023
    if (a_range < 1000 || a_range > 1250)
      $fatal(1, "2023 := range ratio out of bounds: %0d:%0d",
             a_range, a_scalar);
    if (d_range < 625 || d_range > 875)
      $fatal(1, "2023 :/ range ratio out of bounds: %0d:%0d",
             d_range, d_scalar);
`else
    if (a_range < 625 || a_range > 875)
      $fatal(1, "2017 := range ratio out of bounds: %0d:%0d",
             a_range, a_scalar);
    if (d_range < 375 || d_range > 625)
      $fatal(1, "2017 :/ range ratio out of bounds: %0d:%0d",
             d_range, d_scalar);
`endif
    $display("PASS");
    $finish;
  end
endmodule
