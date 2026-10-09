module sv_ref_fork_controls;
  int shared;
  int observed;

  task automatic initializer_exception(ref int value, output int copy_out);
    fork
      automatic int snapshot = value;
      begin
        #1;
        copy_out = snapshot;
      end
    join_none
    #2;
  endtask

  task automatic blocking_join(ref int value);
    fork
      begin
        value = value + 1;
      end
    join
  endtask

  initial begin
    shared = 10;
    initializer_exception(shared, observed);
    wait fork;
    blocking_join(shared);
    if (observed !== 10 || shared !== 11)
      $fatal(1, "ref fork control failed: observed=%0d shared=%0d", observed, shared);
    $display("PASSED");
  end
endmodule
