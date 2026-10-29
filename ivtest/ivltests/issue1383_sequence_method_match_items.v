module issue1383_sequence_method_match_items;
  logic clk = 0;
  logic fire = 0;
  logic assert_fire = 0;
  always #5 clk = ~clk;

  class helper;
    task show_task();
      $display("task-method");
    endtask
    function void show_function();
      $display("void-function-method");
    endfunction
  endclass

  helper h;

  sequence calls;
    @(posedge clk) (fire, h.show_task(), h.show_function());
  endsequence

  cover property (calls);
  assert property (@(posedge clk) disable iff (!assert_fire)
    (assert_fire, h.show_task(), h.show_function()));

  initial begin
    h = new();
    @(negedge clk); fire = 1;
    @(negedge clk); fire = 0; assert_fire = 1;
    @(negedge clk); assert_fire = 0;
    repeat (2) @(negedge clk);
    $display("PASSED");
    $finish(0);
  end
endmodule
