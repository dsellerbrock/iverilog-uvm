module issue1320_vpi_assignment_op_2023;
  logic value;

  initial begin
    value = 1'b1;
    value <= 1'b0;
    #1;
    $display("PASSED");
    $finish;
  end
endmodule
