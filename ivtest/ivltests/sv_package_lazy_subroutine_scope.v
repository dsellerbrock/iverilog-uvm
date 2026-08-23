package package_lazy_subroutine_scope_pkg;
  class caller_base #(type value_t = int);
    extern task run_task();
    extern function int run_function(input value_t value);
  endclass

  class caller extends caller_base#(int);
  endclass

  task caller_base::run_task();
    wait_for_change();
  endtask

  function int caller_base::run_function(input value_t value);
    return add_one(value);
  endfunction

  function automatic int add_one(input int value);
    int scratch;
    scratch = value + 1;
    return scratch;
  endfunction

  task wait_for_change();
    static int nba;
    static int next_nba;
    next_nba++;
    nba <= next_nba;
    @(nba);
  endtask
endpackage

module sv_package_lazy_subroutine_scope;
  package_lazy_subroutine_scope_pkg::caller call;

  initial begin
    call = new;
    if (call.run_function(4) != 5)
      $fatal(1, "lazy package function scope was not preserved");
    call.run_task();
    $display("PASSED");
  end
endmodule
