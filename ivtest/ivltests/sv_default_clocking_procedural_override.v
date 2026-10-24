module main;
  logic clk = 0;
  logic a = 1;
  logic b = 1;
  int fail_a = 0;
  int fail_b = 0;

  always #5 clk = ~clk;

  default clocking @(posedge clk); endclocking

  property a_is_high;
    a;
  endproperty

  // a is low only at the posedge at t=15. b is low only at the negedge
  // at t=20. The procedural assertions below must use the negedge clock.
  initial begin
    #14 a = 0;
    #2 a = 1;
    #3 b = 0;
    #2 b = 1;
    #20;
    if (fail_a == 0 && fail_b == 1)
      $display("PASSED");
    else
      $display("BAD clock selection: a=%0d b=%0d", fail_a, fail_b);
    $finish;
  end

  always @(negedge clk) begin
    assert property (a) else begin
      fail_a++;
      $display("FAIL a %0t", $time);
    end
    assert property (a_is_high) else begin
      fail_a++;
      $display("FAIL named a %0t", $time);
    end
    assert property (b) else begin
      fail_b++;
      $display("FAIL b %0t", $time);
    end
  end
endmodule
