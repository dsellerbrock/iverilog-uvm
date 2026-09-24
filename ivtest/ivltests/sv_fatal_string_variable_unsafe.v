module sv_fatal_string_variable;
  string message = "string-variable value=%0d";
  initial begin
    $fatal(message, 19);
    $display("FAILED: $fatal returned");
  end
endmodule
