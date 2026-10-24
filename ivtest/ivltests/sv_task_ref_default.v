module ref_owner;
  int target = 1;

  task automatic update(ref int value = target);
    value = value + 4;
  endtask
endmodule

module main;
  int target = 20;
  ref_owner owner();

  initial begin
    owner.update();
    if (owner.target !== 5 || target !== 20) begin
      $display("FAIL: owner.target=%0d caller.target=%0d", owner.target, target);
      $finish;
    end
    $display("PASSED");
  end
endmodule
