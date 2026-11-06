// IEEE 1800-2017/2023 16.4: "It shall be an error to pass automatic or
// dynamic variables as actuals to a ref or const ref formal."
module issue442_deferred_action_args_fail;
  int v;
  task automatic rr(ref int y);
    $display("y=%0d", y);
  endtask
  initial begin
    automatic int a = 1;
    assert #0 (v == 1) else rr(a);
  end
endmodule
