interface bus;
  logic x;
endinterface

module top;
  int actual = 7;
  bus b();

  task automatic by_ref(ref int x);
    $issue1271_probe;
  endtask

  task automatic by_vif(virtual interface bus vi);
  endtask

  task automatic directions(input int in_arg, output int out_arg,
                            inout logic io_arg);
  endtask

  function automatic int by_function(input int function_arg);
    return function_arg;
  endfunction

  initial begin
    #0;
    by_ref(actual);
    $finish;
  end
endmodule
