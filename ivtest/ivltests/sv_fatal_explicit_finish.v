module sv_fatal_explicit_finish;
  initial begin
    $fatal(2, "explicit finish value=%0d", 23);
    $display("FAILED: $fatal returned");
  end
endmodule
