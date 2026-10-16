// IEEE 1800-2017/2023 13.4.4: background work is legal when the function
// caller is an initial/always process or a forked process from one.
module sv_function_background_always_fork_ok;
  logic clk = 0;
  integer initial_seen = 0;
  integer always_seen = 0;
  integer fork_seen = 0;
  integer initial_result = 0;
  integer always_result = 0;
  integer fork_result = 0;

  function automatic integer from_initial();
    fork
      initial_seen = 1;
    join_none
    from_initial = from_fork();
  endfunction

  function automatic integer from_fork();
    fork
      fork_seen = 1;
    join_none
    from_fork = 22;
  endfunction

  function automatic integer from_always();
    fork
      always_seen = 1;
    join_none
    from_always = from_fork();
  endfunction

  always @(posedge clk)
    always_result = from_always();

  initial begin
    initial_result = from_initial();
    fork
      fork_result = from_fork();
    join
    #1 clk = 1;
    #1;
    if (initial_seen != 1 || always_seen != 1 || fork_seen != 1 ||
        initial_result != 22 || always_result != 22 || fork_result != 22) begin
      $display("FAIL initial=%0d always=%0d fork=%0d results=%0d/%0d/%0d",
               initial_seen, always_seen, fork_seen,
               initial_result, always_result, fork_result);
      $finish(1);
    end
    $display("PASS");
  end
endmodule
