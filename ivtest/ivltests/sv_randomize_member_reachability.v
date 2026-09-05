// IEEE 1800-2017/2023 18.6.2: enabled objects receive implicit callbacks.
// Either actor may run first; the later one attaches below the earlier one.
class hook_leaf;
  int pre_calls, post_calls;
  function void pre_randomize(); pre_calls++; endfunction
  function void post_randomize(); post_calls++; endfunction
endclass
class hook_actor;
  rand hook_leaf attached;
  rand hook_actor peer;
  int pre_calls, post_calls;
  function void pre_randomize();
    pre_calls++;
    if (peer.pre_calls != 0 && peer.attached == null) peer.attached = new;
  endfunction
  function void post_randomize(); post_calls++; endfunction
endclass
class hook_graph;
  rand hook_actor a, b;
  function new();
    a = new; b = new;
    a.peer = b; b.peer = a;
  endfunction
endclass
module main;
  hook_graph graph = new;
  hook_leaf leaf;
  initial begin
    if (!graph.randomize()) $fatal(1, "unconstrained graph rejected");
    if (graph.a.pre_calls != 1 || graph.b.pre_calls != 1
        || graph.a.post_calls != 1 || graph.b.post_calls != 1)
      $fatal(1, "aliased cyclic actors must receive exactly one callback pair");
    leaf = graph.a.attached;
    if (leaf == null) leaf = graph.b.attached;
    if (leaf == null) $fatal(1, "actor callback did not attach a leaf");
    if (leaf.pre_calls != 1 || leaf.post_calls != 1)
      $fatal(1, "newly reachable leaf without rand fields missed callbacks");
    $display("PASSED");
  end
endmodule
