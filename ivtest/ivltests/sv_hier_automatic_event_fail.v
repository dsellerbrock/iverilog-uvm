// IEEE 1800-2017/2023 6.21: actual automatic events remain inaccessible.
module sv_hier_automatic_event_fail;
  task automatic t();
    event ready;
    @ready;
  endtask
  initial ->t.ready;
endmodule
