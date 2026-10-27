module p35_task;
  import "DPI-C" c_add2 = function int my_add(int a, int b);
  import "DPI-C" context task c_task_call(input int n);
  import "DPI-C" context task c_dis();
  import "DPI-C" function int c_get_flag();
  import "DPI-C" context function int c_disabled_function();
  import "DPI-C" function int c_get_function_flag();
  export "DPI-C" task sv_wait_task;
  export "DPI-C" function sv_disable_function_caller;
  task sv_wait_task(input int n); #n; endtask
  function int sv_disable_function_caller();
    disable function_victim;
    return 123;
  endfunction
  int ignored_function_result;
  initial begin
    $display("A1 %0d", my_add(4, 5));
    c_task_call(5); $display("T1 %0t", $time);
    fork : blk begin c_dis(); $display("NOT_REACHED"); end join_none
    #10 disable blk; #1 $display("T2 %0d %0t", c_get_flag(), $time);
    fork : function_victim
      begin
        ignored_function_result = c_disabled_function();
        $display("FUNCTION_NOT_REACHED");
      end
    join
    $display("F1 %0d", c_get_function_flag());
  end
endmodule
