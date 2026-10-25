module ref_owner;
  int target = 1;

  task automatic update(ref int value = target);
    value = value + 4;
  endtask

  task automatic update_explicit(ref int value);
    value = value + 3;
  endtask
endmodule

module main;
  int target = 20;
  ref_owner owner();

  initial begin
    owner.update();
    if (owner.target !== 5 || target !== 20) begin
      $display("FAIL: default owner.target=%0d caller.target=%0d",
               owner.target, target);
      $finish;
    end

    owner.update_explicit(target);
    if (owner.target !== 5 || target !== 23) begin
      $display("FAIL: explicit owner.target=%0d caller.target=%0d",
               owner.target, target);
      $finish;
    end

    $display("PASSED");
  end
endmodule
