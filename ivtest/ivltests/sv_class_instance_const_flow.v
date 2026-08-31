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
  extern_c external;
  aggregate_c aggregate;
  repeat_covergroup_c range_object;
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
    external = new(8'h41);
    aggregate = new;
    range_object = new;
    detached = new;

    if (zero.value !== 0 || once.value !== 8'h12
        || broken.value !== 8'h13 || second_object.value !== 8'h14
        || exit0.value !== 0 || exit1.value !== 8'h31
        || exit2.value !== 8'h32 || param0.value !== 0
        || param1.value !== 8'h62 || external.value !== 8'h41
        || aggregate.values[0] !== 8'ha1
        || aggregate.values[1] !== 8'ha2 || range_object.limit !== 3
        || detached.value !== 0)
      $fatal(1, "instance-constant value mismatch before detached child");

    #0;
    if (detached.value !== 8'h51)
      $fatal(1, "detached constructor assignment did not execute");
    $display("PASSED");
  end
endmodule
