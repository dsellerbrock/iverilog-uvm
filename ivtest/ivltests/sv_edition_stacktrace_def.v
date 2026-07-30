// Edition gate, defining-edition arm: $stacktrace is legal in
// IEEE 1800-2023 and must work there.
module sv_edition_stacktrace_def;
  initial begin
    $stacktrace;
    $display("PASSED");
  end
endmodule
