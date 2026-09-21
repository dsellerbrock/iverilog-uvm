class cast_exact_width_sum_item;
  rand bit [7:0] a;
  rand bit [7:0] b;

  constraint sum_case {
    a == 8'd250;
    b == 8'd10;
    8'((a + b) / 8'd2) == 8'd2;
    int'((a + b) / 8'd2) == 130;
    8'((a + b) >> 8'd1) == 8'd2;
    int'((a + b) >> 8'd1) == 130;
    8'((a + b) % 8'd3) == 8'd1;
  }
endclass

class cast_exact_width_product_item;
  rand bit [7:0] a;
  rand bit [7:0] b;

  constraint product_case {
    a == 8'd200;
    b == 8'd2;
    8'((a * b) / 8'd2) == 8'd72;
    int'((a * b) / 8'd2) == 200;
  }
endclass

module sv_cast_exact_width_solver;
  cast_exact_width_sum_item sum_item;
  cast_exact_width_product_item product_item;

  initial begin
    sum_item = new;
    if (!sum_item.randomize()) $fatal(1, "sum cast constraints failed");
    if (sum_item.a !== 8'd250 || sum_item.b !== 8'd10)
      $fatal(1, "solver did not preserve sum operands");
    product_item = new;
    if (!product_item.randomize()) $fatal(1, "product cast constraints failed");
    if (product_item.a !== 8'd200 || product_item.b !== 8'd2)
      $fatal(1, "solver did not preserve product operands");
    $display("PASSED");
    $finish(0);
  end
endmodule
