module default_owner;
  int output_target = 2;
  int inout_target = 5;

  task automatic write_output(output int value = output_target[0]);
    value = 1;
  endtask

  task automatic update_inout(inout int value = inout_target);
    value = value + 3;
  endtask
endmodule

module sv_subroutine_output_inout_default;
  default_owner owner();

  initial begin
    owner.write_output();
    owner.update_inout();
    if (owner.output_target !== 3 || owner.inout_target !== 8)
      $display("FAILED output=%0d inout=%0d", owner.output_target,
               owner.inout_target);
    else
      $display("PASSED");
  end
endmodule
