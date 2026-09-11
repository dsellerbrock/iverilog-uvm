module sv_function_background_join;
  int all_bits, all_done, sibling;
  class worker;
    int first_done, late_done;
    function void launch();
      fork
        begin : background_guard
          fork
            #1 first_done = 1;
            #3 late_done = 1;
          join_any
          disable fork;
        end
      join_none
    endfunction
  endclass
  function automatic void launch_all();
    fork
      begin
        fork
          #1 all_bits |= 1;
          #3 all_bits |= 2;
        join
        all_done = 1;
      end
    join_none
  endfunction
  initial begin
    worker w;
    w = new;
    fork #5 sibling = 1; join_none
    w.launch();
    launch_all();
    if ($time != 0 || w.first_done || all_done) $fatal(1, "function blocked");
    #2;
    if (!w.first_done || w.late_done || all_bits != 1 || all_done)
      $fatal(1, "first child or join boundary");
    #2;
    if (w.late_done || all_bits != 3 || !all_done) $fatal(1, "join or cancellation");
    #2;
    if (!sibling) $fatal(1, "unrelated sibling cancelled");
    $display("PASSED");
  end
endmodule
