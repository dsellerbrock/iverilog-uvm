module process_state_marker #(parameter type \process::state = bit [3:0]);
  typedef \process::state local_t;
  initial if ($bits(local_t) != 4) $fatal(1, "escaped type parameter collision");
endmodule

package process_state_pkg;
  typedef process::state state_t;
  function automatic state_t current_state();
    process p;
    p = process::self();
    return p.status();
  endfunction
endpackage

module process_state_child;
  function automatic process::state current_state();
    process p;
    p = process::self();
    return p.status();
  endfunction
endmodule

module sv_process_state_type;
  typedef process::state state_t;
  process_state_child child();
  process_state_marker marker();
  class holder;
    process p;
    function new(); p = process::self(); endfunction
    virtual function process::state current_state(); return p.status(); endfunction
  endclass
  initial begin
    state_t s;
    process_state_pkg::state_t from_pkg;
    process p;
    holder h;
    p = process::self();
    h = new;
    s = p.status();
    if (s != process::RUNNING || s.name() != "RUNNING") $fatal(1, "typed status");
    s = p.status;
    if (s != process::RUNNING) $fatal(1, "parenless typed status");
    s = h.current_state();
    from_pkg = process_state_pkg::current_state();
    s = from_pkg;
    s = child.current_state();
    if (s != process::RUNNING) $fatal(1, "cross-scope identity");
    if ($bits(s) != 32 || s.num() != 5) $fatal(1, "enum width/count");
    s = s.first();
    if (s != process::FINISHED || s != 0 || s.name() != "FINISHED") $fatal(1, "first");
    s = s.next();
    if (s != process::RUNNING || s != 1 || s.name() != "RUNNING") $fatal(1, "running");
    s = process::WAITING;
    if (s != 2 || s.name() != "WAITING") $fatal(1, "waiting");
    s = process::SUSPENDED;
    if (s != 3 || s.name() != "SUSPENDED") $fatal(1, "suspended");
    s = s.last();
    if (s != process::KILLED || s != 4 || s.name() != "KILLED") $fatal(1, "last");
    s = s.next();
    if (s != process::FINISHED) $fatal(1, "wrap");
    s = state_t'(-1);
    if (s >= 0 || s.name() != "") $fatal(1, "signed enum cast");
    $display("PASSED");
  end
endmodule
