// IEEE 1800-2017/2023 13.3.1, 13.4.2, 13.5.1, 13.5.3 and 25.9:
// defaults may modify earlier static formals, a queue input remains a
// by-value copy, nested calls during argument setup preserve the outer setup,
// and recursion from the executing static body retains shared storage.
interface vif_static_formal_if;
  function int scalar_default(
      input int first, input int second = (first = 99));
    return first;
  endfunction

  function automatic int append_ten(ref int values[$]);
    values.push_back(10);
    return values.size();
  endfunction

  function int queue_default(
      input int values[$], input int count = append_ten(values));
    if (count != 2 || values.size() != 2)
      return -1;
    return values[0] + values[1];
  endfunction

  function int setup_fold(input int first, input int second);
    return first * 10 + second;
  endfunction

  function int nested_default_overlay(
      input int first, input virtual vif_static_formal_if self,
      input int mode,
      input int second =
          mode ? self.nested_default_overlay((first = 9), self, 0, 3) : 3);
    return first * 100 + second;
  endfunction

  function int body_recurse(
      input int depth, input int seed,
      input virtual vif_static_formal_if self);
    if (depth > 0) begin
      if (self.body_recurse(depth - 1, seed + 1, self) < 0)
        return -1;
    end
    return depth * 100 + seed;
  endfunction
endinterface

module sv_vif_function_static_formal_semantics;
  vif_static_formal_if dut_if();
  virtual vif_static_formal_if vif;
  int caller[$];
  int got;

  initial begin
    vif = dut_if;

    got = vif.scalar_default(1);
    if (got !== 99)
      $fatal(1, "scalar default side effect: got %0d", got);

    caller.push_back(3);
    got = vif.queue_default(caller);
    if (got !== 13)
      $fatal(1, "queue default side effect: got %0d", got);
    if (caller.size() != 1 || caller[0] != 3)
      $fatal(1, "queue actual changed: size %0d first %0d",
             caller.size(), caller[0]);

    got = vif.setup_fold(4, vif.setup_fold(7, 3));
    if (got !== 113)
      $fatal(1, "nested actual setup: got %0d", got);

    got = vif.nested_default_overlay(4, vif, 1);
    if (got !== 1803)
      $fatal(1, "nested default overlay: got %0d", got);

    got = vif.body_recurse(3, 40, vif);
    if (got !== 43)
      $fatal(1, "static body sharing: got %0d", got);

    $display("PASSED");
  end
endmodule
