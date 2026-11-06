// IEEE 1800-2017/2023 16.4: an action argument is passed by value as an
// input or by reference as a ref or const ref; an output is illegal.
module issue442_deferred_action_output_fail;
  int v;
  task automatic ro(output int y);
    y = 3;
  endtask
  initial assert #0 (v == 1) else ro(v);
endmodule
