// Edition gate, neighbour arm: gating $stacktrace must not disturb the
// ordinary system tasks that share its elaboration path, which remain
// legal in every edition.
module sv_edition_stacktrace_neighbour;
  initial begin
    $display("display works");
    $write("write works\n");
    if ($time == 0) $display("PASSED");
  end
endmodule
