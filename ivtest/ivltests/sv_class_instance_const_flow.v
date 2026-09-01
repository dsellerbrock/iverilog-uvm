// IEEE 1800-2017/2023 8.19: instance constants are initialized by at
// most one executed assignment in the corresponding constructor. A
// constructor is not required to assign every instance constant.
module top;
  class dynamic_loop_c;
    const bit [7:0] value;
    function new(int count, bit stop_after_first, bit [7:0] v);
      repeat (count) begin
        value = v;
        if (stop_after_first)
          break;
      end
    endfunction
  endclass

  class early_exit_c;
    const bit [7:0] value;
    function new(int mode);
      if (mode == 0)
        return;
      if (mode == 1) begin
        value = 8'h31;
        return;
      end
      value = 8'h32;
    endfunction
  endclass

  class param_loop_c #(int N = 0, bit [7:0] V = 0);
    const bit [7:0] value;
    function new;
      repeat (N)
        value = V;
    endfunction
  endclass

  class literal_repeat_c;
    const bit [7:0] value;
    function new;
      repeat (0)
        value = 8'h70;
      repeat (1)
        value = 8'h71;
    endfunction
  endclass

  class extern_c;
    const bit [7:0] value;
    extern function new(bit [7:0] v);
  endclass

  function extern_c::new(bit [7:0] v);
    value = v;
  endfunction

  class aggregate_c;
    const bit [7:0] values[2];
    function new;
      values = '{8'ha1, 8'ha2};
    endfunction
  endclass

  class multiple_property_c;
    int mutable_prefix;
    const bit [7:0] first;
    const bit [7:0] second;
    function new;
      mutable_prefix = 7;
      first = 8'hb1;
      second = 8'hb2;
    endfunction
  endclass

  class base_constant_c;
    const bit [7:0] base_value;
    function new;
      base_value = 8'hc1;
    endfunction
  endclass

  class derived_constant_c extends base_constant_c;
    const bit [7:0] derived_value;
    function new;
      super.new;
      derived_value = 8'hc2;
    endfunction
  endclass

  class repeat_covergroup_c;
    const int limit;
    covergroup cg with function sample(int value);
      cp: coverpoint value {
        bins in_range = {[0:limit]};
      }
    endgroup
    function new;
      repeat (1)
        limit = 3;
      cg = new;
    endfunction
  endclass

  class parameter_repeat_covergroup_c #(int N = 1);
    const int limit;
    covergroup cg with function sample(int value);
      cp: coverpoint value {
        bins in_range = {[0:limit]};
      }
    endgroup
    function new;
      repeat (N)
        limit = 4;
      cg = new;
    endfunction
  endclass

  class for_header_base_c;
    const bit [7:0] header_base;
    function new(bit [7:0] v, bit enter_body);
      for (header_base = v; enter_body; )
        $fatal(1, "zero-trip base for-loop entered its body");
    endfunction
  endclass

  class for_header_derived_c extends for_header_base_c;
    const bit [7:0] unqualified_value;
    const bit [7:0] qualified_value;
    function new(bit [7:0] base_v, bit [7:0] plain_v,
                 bit [7:0] qualified_v, bit enter_body);
      super.new(base_v, enter_body);
      for (unqualified_value = plain_v; enter_body; )
        $fatal(1, "zero-trip unqualified for-loop entered its body");
      for (this.qualified_value = qualified_v; enter_body; )
        $fatal(1, "zero-trip qualified for-loop entered its body");
    endfunction
  endclass

  class for_header_covergroup_c;
    const int limit;
    covergroup cg with function sample(int value);
      cp: coverpoint value {
        bins in_range = {[0:limit]};
      }
    endgroup
    function new(int v, bit run_once);
      // The initializer executes before the loop body. IEEE 1800 19.5
      // prohibits the two assignments from appearing together in the body
      // of a loop; the for-header initializer is not part of that body.
      for (limit = v; run_once; run_once = 0)
        cg = new;
    endfunction
  endclass

  class for_break_covergroup_c;
    const int limit;
    covergroup cg with function sample(int value);
      cp: coverpoint value {
        bins in_range = {[0:limit]};
      }
    endgroup
    function new(int v);
      // An omitted condition guarantees entry. The break is therefore the
      // only normal exit and carries LIMIT's definite initialization.
      for (;;) begin
        limit = v;
        break;
      end
      cg = new;
    endfunction
  endclass

  class for_literal_false_covergroup_c;
    const int limit;
    covergroup cg with function sample(int value);
      cp: coverpoint value {
        bins in_range = {[0:limit]};
      }
    endgroup
    function new(int v);
      // A defined-false condition makes the body unreachable. Its
      // constructor call therefore cannot precede the initializer below.
      for (; 1'b0; )
        cg = new;
      limit = v;
      cg = new;
    endfunction
  endclass

  class for_literal_true_covergroup_c;
    const int limit;
    covergroup cg with function sample(int value);
      cp: coverpoint value {
        bins in_range = {[0:limit]};
      }
    endgroup
    function new(int v);
      // A defined-true condition guarantees entry, and the break carries
      // LIMIT's initialized state to the code following the loop.
      for (; 1'b1; ) begin
        limit = v;
        break;
      end
      cg = new;
    endfunction
  endclass

  class for_break_step_c;
    int index;
    const bit [7:0] value;
    function new;
      // A break exits directly and must not execute the duplicate-writing
      // step assignment.
      for (value = 8'hf1; index < 1; value = 8'hf2) begin
        index = 1;
        break;
      end
    endfunction
  endclass

  class fork_once_c;
    const bit [7:0] value;
    function new;
      fork
        this.value = 8'h51;
      join_none
    endfunction
  endclass

  dynamic_loop_c zero, once, broken, second_object;
  early_exit_c exit0, exit1, exit2;
  param_loop_c#(0, 8'h61) param0;
  param_loop_c#(1, 8'h62) param1;
  literal_repeat_c literal_repeat;
  extern_c external;
  aggregate_c aggregate;
  multiple_property_c multiple;
  derived_constant_c derived;
  repeat_covergroup_c range_object;
  parameter_repeat_covergroup_c#(1) parameter_range_object;
  for_header_derived_c header_object1, header_object2;
  for_header_covergroup_c header_range_object;
  for_break_covergroup_c break_range_object;
  for_literal_false_covergroup_c false_range_object;
  for_literal_true_covergroup_c true_range_object;
  for_break_step_c break_step_object;
  fork_once_c detached;

  initial begin
    zero = new(0, 0, 8'h11);
    once = new(1, 0, 8'h12);
    broken = new(3, 1, 8'h13);
    second_object = new(1, 0, 8'h14);
    exit0 = new(0);
    exit1 = new(1);
    exit2 = new(2);
    param0 = new;
    param1 = new;
    literal_repeat = new;
    external = new(8'h41);
    aggregate = new;
    multiple = new;
    derived = new;
    range_object = new;
    parameter_range_object = new;
    header_object1 = new(8'hd1, 8'hd2, 8'hd3, 0);
    header_object2 = new(8'he1, 8'he2, 8'he3, 0);
    header_range_object = new(6, 1);
    break_range_object = new(7);
    false_range_object = new(8);
    true_range_object = new(9);
    break_step_object = new;
    detached = new;

    if (zero.value !== 0 || once.value !== 8'h12
        || broken.value !== 8'h13 || second_object.value !== 8'h14
        || exit0.value !== 0 || exit1.value !== 8'h31
        || exit2.value !== 8'h32 || param0.value !== 0
        || param1.value !== 8'h62 || literal_repeat.value !== 8'h71
        || external.value !== 8'h41
        || aggregate.values[0] !== 8'ha1
        || aggregate.values[1] !== 8'ha2
        || multiple.mutable_prefix !== 7 || multiple.first !== 8'hb1
        || multiple.second !== 8'hb2 || derived.base_value !== 8'hc1
        || derived.derived_value !== 8'hc2 || range_object.limit !== 3
        || parameter_range_object.limit !== 4
        || header_object1.header_base !== 8'hd1
        || header_object1.unqualified_value !== 8'hd2
        || header_object1.qualified_value !== 8'hd3
        || header_object2.header_base !== 8'he1
        || header_object2.unqualified_value !== 8'he2
        || header_object2.qualified_value !== 8'he3
        || header_range_object.limit !== 6
        || break_range_object.limit !== 7
        || false_range_object.limit !== 8
        || true_range_object.limit !== 9
        || break_step_object.value !== 8'hf1
        || detached.value !== 0)
      $fatal(1, "instance-constant value mismatch before detached child");

    #0;
    if (detached.value !== 8'h51)
      $fatal(1, "detached constructor assignment did not execute");
    $display("PASSED");
  end
endmodule
