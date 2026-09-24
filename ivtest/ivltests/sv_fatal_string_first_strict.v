module sv_fatal_string_first;
  initial begin
    $fatal("string-first value=%0d", 17);
    $display("FAILED: $fatal returned");
  end
endmodule
