class issue2602_cfg;
  rand bit [7:0] g[][];
  constraint values {
    g.size == 2;
    foreach (g[r]) g[r].size == r + 2;
    foreach (g[r, k]) g[r][k] == r * 16 + k;
  }
endclass

class issue2602_direct_owner;
  rand issue2602_cfg c;
  rand bit [7:0] x;
  constraint direct { x == c.g[1][2] + 1; }
  function new; c = new; endfunction
endclass

class issue2602_foreach_owner;
  rand issue2602_cfg c;
  rand bit [7:0] x;
  constraint iterated {
    foreach (c.g[r, k])
      if (r == 1 && k == 2) x == c.g[r][k] + 1;
  }
  function new; c = new; endfunction
endclass

module issue2602_nested_object_dynamic_array2;
  initial begin
    issue2602_direct_owner direct_owner;
    issue2602_foreach_owner foreach_owner;
    direct_owner = new;
    foreach_owner = new;

    if (!direct_owner.randomize() || direct_owner.x != 19)
      $fatal(1, "direct nested dynamic-array constraint failed");
    if (direct_owner.randomize() with { x != 19; })
      $fatal(1, "direct nested dynamic-array constraint was ignored");
    direct_owner.c = null;
    if (direct_owner.randomize())
      $fatal(1, "direct constraint accepted a null rand handle");

    if (!foreach_owner.randomize() || foreach_owner.x != 19)
      $fatal(1, "foreach nested dynamic-array constraint failed");
    if (foreach_owner.randomize() with { x != 19; })
      $fatal(1, "foreach nested dynamic-array constraint was ignored");
    foreach_owner.c = null;
    if (foreach_owner.randomize())
      $fatal(1, "foreach constraint accepted a null rand handle");

    $display("PASSED");
  end
endmodule
