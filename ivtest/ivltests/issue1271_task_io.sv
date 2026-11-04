interface bus;
  logic x;
endinterface

module issue1271_task_io;
  logic [3:0] actual;

  task automatic by_value(input int a, output int b, inout int c);
  endtask

  function automatic int by_function(input int arg);
    by_function = arg;
  endfunction

  task automatic by_ref(ref logic [3:0] x);
    begin
      $probe_task_ref();
    end
  endtask

  task automatic by_vif(virtual interface bus vi);
  endtask

  initial begin
    actual = 4'h5;
    #0;
    $probe_task_decls();
    by_ref(actual);
    $display("PASSED");
    $finish;
  end
endmodule
