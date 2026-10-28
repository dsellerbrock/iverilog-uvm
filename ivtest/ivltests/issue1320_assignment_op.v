module issue1320_assignment_op;
  int blocking_value;
  int nonblocking_value;

  initial begin
    blocking_value = 1;
    nonblocking_value <= 2;
    #1;
`ifdef ISSUE1320_VPI_HEADER
    $probe_assignment_op;
`endif
    $display("PASSED");
    $finish;
  end
endmodule
