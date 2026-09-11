// IEEE 1800-2017/2023 6.21: explicitly static event in automatic scope.
module sv_hier_static_event;
  int seen;
  task automatic wait_ready();
    static event ready;
    @ready;
    seen++;
  endtask
  initial begin
    fork wait_ready(); join_none
    #1;
    ->wait_ready.ready;
    #1;
    if (seen !== 1) $fatal(1, "static event hierarchical trigger");
    $display("PASSED");
  end
endmodule
