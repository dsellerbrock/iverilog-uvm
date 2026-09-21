class receiver_state_source;
  logic [7:0] value;
  virtual function logic [7:0] read(); return value; endfunction
endclass
class receiver_state_holder;
  receiver_state_source state;
endclass
class receiver_state_item;
  rand bit [7:0] result;
  bit enable;
  receiver_state_holder path;
  receiver_state_source xstate;
  int posts;
  constraint null_c { if (enable) result == path.state.read(); }
  constraint x_c { if (enable) result == xstate.read(); }
  function new;
    path = new;
    xstate = new;
    xstate.value = 8'hx5;
  endfunction
  function void post_randomize(); posts++; endfunction
endclass
module test;
  receiver_state_item value;
  string rng;
  bit [7:0] old_result;
  task automatic expect_failure(input string label);
    old_result = value.result;
    rng = value.get_randstate();
    if (value.randomize()) $fatal(1, "%s succeeded", label);
    if (value.result != old_result || value.get_randstate() != rng
        || value.posts != 1)
      $fatal(1, "%s lost value/RNG/callback rollback", label);
  endtask
  initial begin
    value = new;
    value.srandom(32'h4e554c4c);
    value.null_c.constraint_mode(0);
    value.x_c.constraint_mode(0);
    if (!value.randomize() || value.posts != 1)
      $fatal(1, "disabled blocks invoked methods");

    value.null_c.constraint_mode(1);
    value.enable = 0;
    value.result = 8'h91;
    expect_failure("terminal null false guard");
    value.enable = 1;
    value.result = 8'h92;
    expect_failure("terminal null true guard");
    value.path = null;
    value.result = 8'h93;
    expect_failure("intermediate null");

    value.null_c.constraint_mode(0);
    value.x_c.constraint_mode(1);
    value.enable = 0;
    value.result = 8'h94;
    expect_failure("X result false guard");
    value.enable = 1;
    value.result = 8'h95;
    expect_failure("X result true guard");
    $display("PASSED");
  end
endmodule
