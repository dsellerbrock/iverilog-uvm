module test;
  string source = "first";
  string sink;
  int updates;
  assign sink = source;
  always @(sink) updates++;

  initial begin
    #1;
    if (updates != 1) $fatal(1, "initial update count: %0d", updates);
    source = "second";
    #1;
    if (updates != 2) $fatal(1, "changed update count: %0d", updates);
    source = "second";
    #1;
    if (updates != 2) $fatal(1, "unchanged update count: %0d", updates);
    source = "";
    #1;
    if (updates != 3) $fatal(1, "empty update count: %0d", updates);
    $display("PASS string update count");
  end
endmodule
