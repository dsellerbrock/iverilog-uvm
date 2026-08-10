module t;
  task automatic fork_source;
    assert final (0) else $display("FORK_SCOPE %m");
  endtask

  function automatic integer function_source(input bit ok);
    assert final (ok) else $display("FUNCTION_SCOPE %m");
    function_source = 0;
  endfunction

  class c;
    function void class_source(input bit ok);
      assert final (ok) else $display("CLASS_SCOPE %m");
    endfunction
  endclass

  c obj;
  integer sink;
  initial begin : contexts
    obj = new;
    sink = function_source(0);
    obj.class_source(0);
    // The same source assertion in distinct fork processes reports twice.
    fork
      fork_source();
      begin
        #0;
        fork_source();
      end
    join
    #1 $display("PASSED");
  end
endmodule
