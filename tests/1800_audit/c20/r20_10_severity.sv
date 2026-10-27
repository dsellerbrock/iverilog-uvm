module p20sev;
 initial begin
  $info("info %0d", 1); $display("LOC1 %s:%0d", `__FILE__, `__LINE__);
  $warning("warn %s", "w"); $display("LOC2 %s:%0d", `__FILE__, `__LINE__);
  $error("err %h", 8'hAB); $display("LOC3 %s:%0d", `__FILE__, `__LINE__);
  #5 $error; $display("AFTER_ERROR_NOARG");
  #1 $fatal(1, "fatal %0d", 42);
  $display("AFTER_FATAL");
 end
endmodule
