// Edition gate, older-mode arm: $stacktrace is IEEE 1800-2023. Under an
// edition that predates it the compile must FAIL, and the diagnostic
// must name the construct, the edition and the flag (pinned by the
// gold file). Before the edition gates it compiled and RAN here,
// giving a user who asked for 1800-2012 a 2023 feature silently.
module sv_edition_stacktrace_2017;
  initial begin
    $stacktrace;
    $display("FAILED -- should not have compiled under -g2017");
  end
endmodule
