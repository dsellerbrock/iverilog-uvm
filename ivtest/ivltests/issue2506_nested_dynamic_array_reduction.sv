class c;
  rand bit [7:0] s[][];
  constraint cs {
    foreach (s[i]) s[i].sum() with (int'(item)) == 10 * (i + 1);
    foreach (s[i]) s[i].sum() == 8'(10 * (i + 1));
    foreach (s[i, j]) s[i][j] < 8'd30;
  }
endclass

module issue2506_nested_dynamic_array_reduction;
  c o = new;
  int t0, t1;
  initial begin
    o.s = new[2];
    o.s[0] = new[2];
    o.s[1] = new[3];
    if (!o.randomize()) begin
      $display("FAILED randomize");
      $finish;
    end
    foreach (o.s[0][j]) t0 += o.s[0][j];
    foreach (o.s[1][j]) t1 += o.s[1][j];
    if (o.s.size() != 2 || o.s[0].size() != 2 || o.s[1].size() != 3
        || t0 != 10 || t1 != 20) begin
      $display("FAILED sizes/sums %0d %0d %0d %0d",
               o.s[0].size(), o.s[1].size(), t0, t1);
      $finish;
    end
    foreach (o.s[i, j])
      if (o.s[i][j] >= 30) begin
        $display("FAILED bound");
        $finish;
      end
    $display("s %0d %0d %0d %0d", o.s[0].size(), o.s[1].size(), t0, t1);
  end
endmodule
