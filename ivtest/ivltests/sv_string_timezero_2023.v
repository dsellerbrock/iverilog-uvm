module test;
  string source = "initial";
  string sink;
  assign sink = source;

  initial begin
    #0;
    if (sink != "initial") $fatal(1, "time-zero initial: %s", sink);
    source = "changed at zero";
    #0;
    if (sink != "changed at zero") $fatal(1, "time-zero update: %s", sink);
    $display("PASS string timezero");
  end
endmodule
