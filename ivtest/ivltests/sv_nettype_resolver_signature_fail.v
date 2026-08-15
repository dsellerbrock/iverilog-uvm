module sv_nettype_resolver_signature_fail;
  function automatic logic [7:0] no_argument();
    return '0;
  endfunction

  function automatic logic [3:0] wrong_return(input logic [7:0] drivers[]);
    return drivers.size() ? drivers[0][3:0] : '0;
  endfunction

  function automatic logic [7:0] fixed_argument(input logic [7:0] drivers[2]);
    return drivers[0];
  endfunction

  task automatic task_resolver(input logic [7:0] drivers[]);
  endtask

  nettype logic [7:0] no_argument_net with no_argument;
  nettype logic [7:0] wrong_return_net with wrong_return;
  nettype logic [7:0] fixed_argument_net with fixed_argument;
  nettype logic [7:0] task_resolver_net with task_resolver;
endmodule
