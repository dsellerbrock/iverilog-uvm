// IEEE 1800-2017/2023 18.6.2, 18.6.3 and 18.11.
class hook_node;
  rand int value = 3;
  rand hook_node child;
  bit spawn_child;
  int pre_calls, post_calls;
  function void pre_randomize();
    pre_calls++;
    value = 7;
    if (spawn_child && child == null) child = new;
  endfunction
  function void post_randomize(); post_calls++; endfunction
endclass
class hook_root;
  rand hook_node member;
  bit reject = 1, detach;
  int pre_calls, post_calls;
  constraint c { reject == 0; }
  function void pre_randomize();
    pre_calls++;
    if (member == null) begin member = new; member.spawn_child = 1; end
  endfunction
  function void post_randomize();
    post_calls++;
    if (detach) member = null;
  endfunction
endclass
module main;
  hook_root root = new;
  hook_node saved, grandchild;
  initial begin
    if (root.randomize()) $fatal(1, "infeasible root accepted");
    saved = root.member;
    if (saved.pre_calls != 1 || saved.post_calls != 0 || saved.value != 7)
      $fatal(1, "member pre/failure barrier: pre=%0d post=%0d value=%0d",
             saved.pre_calls, saved.post_calls, saved.value);
    grandchild = saved.child;
    if (grandchild == null) $fatal(1, "member pre allocation skipped");
    if (grandchild.pre_calls != 1 || grandchild.post_calls != 0 || grandchild.value != 7)
      $fatal(1, "grandchild pre/failure barrier");
    if (root.pre_calls != 1 || root.post_calls != 0) $fatal(1, "root failure hooks");
    root.reject = 0;
    if (!root.randomize(null)) $fatal(1, "checker rejected");
    if (root.pre_calls != 2 || root.post_calls != 1 || saved.pre_calls != 1)
      $fatal(1, "checker must invoke only root hooks");
    root.detach = 1;
    if (!root.randomize(member)) $fatal(1, "selected member solve rejected");
    if (root.member != null || root.pre_calls != 3 || root.post_calls != 2)
      $fatal(1, "root post did not detach solved member");
    if (saved.pre_calls != 2 || saved.post_calls != 1
        || grandchild.pre_calls != 2 || grandchild.post_calls != 1)
      $fatal(1, "solved member post receivers were lost");
    $display("PASSED");
  end
endmodule
