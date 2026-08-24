// IEEE 1800-2017/2023 18.6.2: every class has implicit empty
// pre_randomize() and post_randomize() void functions. Calls through an
// implicit this, an explicit super, and a receiver expression must all work;
// user-declared hooks must retain their ordinary bodies.
class empty_hook_base;
  int body_calls;

  function void call_implicit_hooks();
    pre_randomize();
    this.post_randomize();
    body_calls++;
  endfunction
endclass

class implicit_super_child extends empty_hook_base;
  rand int value;
  int pre_calls;
  int post_calls;

  function void pre_randomize();
    super.pre_randomize();
    pre_calls++;
  endfunction

  function void post_randomize();
    super.post_randomize();
    post_calls++;
  endfunction
endclass

class declared_hook_base;
  int pre_calls;
  int post_calls;

  function void pre_randomize();
    pre_calls++;
  endfunction

  function void post_randomize();
    post_calls++;
  endfunction
endclass

class declared_hook_child extends declared_hook_base;
  function void call_super_hooks();
    super.pre_randomize();
    super.post_randomize();
  endfunction
endclass

module test;
  empty_hook_base empty_object;
  declared_hook_base declared_object;
  int empty_receiver_evals;
  int declared_receiver_evals;

  function empty_hook_base make_empty_object();
    empty_receiver_evals++;
    return empty_object;
  endfunction

  function declared_hook_base make_declared_object();
    declared_receiver_evals++;
    return declared_object;
  endfunction

  initial begin
    implicit_super_child implicit_child;
    declared_hook_child declared_child;

    empty_object = new;
    empty_object.pre_randomize();
    empty_object.post_randomize();
    empty_object.call_implicit_hooks();
    if (empty_object.body_calls != 1)
      $fatal(1, "implicit-this hook calls changed the enclosing body");

    make_empty_object().pre_randomize();
    make_empty_object().post_randomize();
    if (empty_receiver_evals != 2)
      $fatal(1, "empty hook receiver evaluated %0d times",
             empty_receiver_evals);

    implicit_child = new;
    implicit_child.pre_randomize();
    implicit_child.post_randomize();
    if (implicit_child.pre_calls != 1 || implicit_child.post_calls != 1)
      $fatal(1, "implicit-super hooks: pre=%0d post=%0d",
             implicit_child.pre_calls, implicit_child.post_calls);
    if (!implicit_child.randomize())
      $fatal(1, "randomize with implicit super hooks failed");
    if (implicit_child.pre_calls != 2 || implicit_child.post_calls != 2)
      $fatal(1, "randomize hooks: pre=%0d post=%0d",
             implicit_child.pre_calls, implicit_child.post_calls);

    declared_child = new;
    declared_child.call_super_hooks();
    if (declared_child.pre_calls != 1 || declared_child.post_calls != 1)
      $fatal(1, "declared super hooks were not preserved");

    declared_object = declared_child;
    make_declared_object().pre_randomize();
    make_declared_object().post_randomize();
    if (declared_receiver_evals != 2
        || declared_child.pre_calls != 2 || declared_child.post_calls != 2)
      $fatal(1, "declared receiver hooks: eval=%0d pre=%0d post=%0d",
             declared_receiver_evals, declared_child.pre_calls,
             declared_child.post_calls);

    $display("PASSED");
  end
endmodule
