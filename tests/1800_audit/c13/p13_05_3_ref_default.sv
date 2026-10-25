// IEEE 1800-2017 §13.5.3 (p. 332):
// The optional direction can be input, inout, output, or ref.
module test;
  int target = 100;
  task automatic step_ref(ref int r = target);
    r = r + 1;
  endtask

  initial begin
    step_ref();
    if (target === 101) $display("PASS 13.5.3 ref default argument target=%0d", target);
    else $fatal(1, "FAIL 13.5.3 ref default argument target=%0d", target);
  end
endmodule
