module test;
  string source = "zero";
  string sink;
  assign #0 sink = source;
  initial begin
    #1;
    if (sink != "zero") $fatal(1, "zero delay initial: %s", sink);
    source = "updated";
    #1;
    if (sink != "updated") $fatal(1, "zero delay update: %s", sink);
    $display("PASS string zero delay");
  end
endmodule
