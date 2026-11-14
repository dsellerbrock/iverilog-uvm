module issue3309_dist_property;
  reg clk = 0;
  reg [1:0] x = 0;
  integer failures = 0, covers = 0, implication_failures = 0, guard_failures = 0;
  always #5 clk = ~clk;

  property membership;
    @(posedge clk) x dist {0 := 0, [1:2] :/ 0};
  endproperty
  assert property (membership) else failures = failures + 1;
  cover property (@(posedge clk) x dist {0 := 0, [1:2] :/ 0}) covers = covers + 1;
  assert property (@(posedge clk) (x == 3) |-> x dist {0, [1:2] :/ 7})
    else implication_failures = implication_failures + 1;
  assert property (@(posedge clk) x dist {0, [1:2] := 0} throughout 1)
    else guard_failures = guard_failures + 1;
`ifdef TEST_2023
  assert property (@(posedge clk) x dist {0 := 0, default :/ 0})
    else $fatal(1, "default range did not match");
`endif

  initial begin
    #12 x = 3;
    #10 x = 1;
    #10 x = 2;
    #10;
    if (failures != 1 || covers != 3 || implication_failures != 1 || guard_failures != 1) begin
      $display("FAIL failures=%0d covers=%0d implication_failures=%0d guard_failures=%0d", failures, covers, implication_failures, guard_failures);
      $finish_and_return(1);
    end
    $display("PASS");
    $finish(0);
  end
endmodule
