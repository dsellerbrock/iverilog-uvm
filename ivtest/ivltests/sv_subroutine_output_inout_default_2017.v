module defaults;
  logic output_target = 1'b0;
  logic inout_target = 1'b1;

  task set_output(output logic value = output_target);
    value = 1'b1;
  endtask

  task toggle_inout(inout logic value = inout_target);
    value = ~value;
  endtask
endmodule

module test;
  logic output_target = 1'b0;
  logic inout_target = 1'b0;
  logic explicit_output = 1'b0;
  logic explicit_inout = 1'b1;
  defaults d();

  initial begin
    d.set_output();
    d.toggle_inout();
    d.set_output(explicit_output);
    d.toggle_inout(explicit_inout);
    if (d.output_target !== 1'b1 || d.inout_target !== 1'b0 ||
        output_target !== 1'b0 || inout_target !== 1'b0 ||
        explicit_output !== 1'b1 || explicit_inout !== 1'b0) begin
      $display("FAIL");
      $finish;
    end
    $display("PASS");
  end
endmodule
