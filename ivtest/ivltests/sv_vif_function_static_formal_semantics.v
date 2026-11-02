// IEEE 1800-2017/2023 13.3.1, 13.4.2, 13.5.1, 13.5.3 and 25.9:
// defaults resolve in declaration scope even when a formal has the same name;
// a queue input remains a by-value copy, nested calls during argument setup
// preserve the outer setup, and recursion in a static body retains shared
// storage.
interface vif_static_formal_if;
  int first = 0;
  int mode = 0;
  int values[$];

  function int scalar_default(
      input int first, input int second = (first = 99));
    return second;
  endfunction

  function automatic int append_ten(ref int values[$]);
    values.push_back(10);
    return values.size();
  endfunction

  function int queue_default(
      input int values[$], input int count = append_ten(values));
    if (count != 2 || values.size() != 1)
      return -1;
    return values[0] + count;
  endfunction

  function int setup_fold(input int first, input int second);
    return first * 10 + second;
  endfunction

  function int nested_default_overlay(
      input int first, input int mode,
      input int second =
          mode ? setup_fold((first = 9), 0) : 3);
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
    dut_if.first = 1;

    got = vif.scalar_default(1);
    if (got !== 99)
      $fatal(1, "scalar declaration-scope default: got %0d", got);
    if (dut_if.first !== 99)
      $fatal(1, "scalar default did not update declaration-scope state");

    dut_if.values.push_back(2);
    caller.push_back(3);
    got = vif.queue_default(caller);
    if (got !== 5)
      $fatal(1, "queue default side effect: got %0d", got);
    if (caller.size() != 1 || caller[0] != 3)
      $fatal(1, "queue actual changed: size %0d first %0d",
             caller.size(), caller[0]);
    if (dut_if.values.size() != 2 || dut_if.values[1] != 10)
      $fatal(1, "queue default did not update declaration-scope state");

    got = vif.setup_fold(4, vif.setup_fold(7, 3));
    if (got !== 113)
      $fatal(1, "nested actual setup: got %0d", got);

    dut_if.first = 4;
    dut_if.mode = 1;
    got = vif.nested_default_overlay(4, 1);
    if (got !== 490 || dut_if.first !== 9)
      $fatal(1, "nested default overlay: got %0d", got);

    got = vif.body_recurse(3, 40, vif);
    if (got !== 43)
      $fatal(1, "static body sharing: got %0d", got);

    $display("PASSED");
  end
endmodule
