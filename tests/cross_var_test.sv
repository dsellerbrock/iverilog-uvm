// Cross-variable constraint test: a < b, both constrained together
class CrossItem;
  rand bit [7:0] a;
  rand bit [7:0] b;
  constraint c1 { a < b; b < 8'd100; a > 8'd10; }
endclass

module cross_var_test;
  CrossItem item;
  int failed = 0;
  initial begin
    item = new();
    repeat (10) begin
      if (!item.randomize())
        $display("RANDOMIZE FAILED");
      else begin
        $display("a=%0d b=%0d", item.a, item.b);
        if (item.a >= item.b || item.b >= 100 || item.a <= 10)
          failed++;
      end
    end
    if (failed == 0)
      $display("Cross-variable constraint test PASSED!");
    else
      $display("FAILED: %0d violations", failed);
  end
endmodule
