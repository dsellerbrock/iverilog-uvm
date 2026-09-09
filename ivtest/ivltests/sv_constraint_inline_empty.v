// Empty inline blocks and zero-iteration foreach are valid, not lowering failures.
class item;
  rand int value;
  rand int data[];
  int posts;
  constraint size_c { data.size() == 0; }
  function void post_randomize(); posts++; endfunction
endclass
module main;
  item req = new;
  initial begin
    if (!req.randomize() with {}) $fatal(1, "empty inline block failed");
    if (!req.randomize() with {
      value == 123;
      foreach (data[i]) data[i] == 9;
    } || req.value != 123 || req.data.size() != 0)
      $fatal(1, "empty iteration or adjacent constraint failed");
    void'(req.randomize() with { value == 17; });
    if (req.value != 17 || req.posts != 3) $fatal(1, "task call or callbacks failed");
    $display("PASSED");
  end
endmodule
