`line 17 "issue1344_runtime_error.sv" 0
module top;
  initial begin
`ifdef TEST_FATAL
    #1 $fatal(1, "fatal %0d", 31);
    #1 $display("UNREACHABLE");
`else
    #1 $error("error %0d", 17);
    $warning("warning control");
    $info("info control");
    #1 $error("error %0d", 23);
    $display("CONTINUED");
`endif
  end
endmodule
