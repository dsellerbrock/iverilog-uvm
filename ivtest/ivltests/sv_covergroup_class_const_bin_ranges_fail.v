// IEEE 1800-2017/2023 8.19 and 19.5: illegal enclosing-class
// references and instance-constant/covergroup construction order.
module top;
  localparam int SHADOW_LIMIT = 9;

  class c01_mutable_shadow;
    int SHADOW_LIMIT;
    covergroup cg_shadow with function sample(int value);
      cp: coverpoint value {
        bins mutable_shadow = {[0:SHADOW_LIMIT]};
      }
    endgroup
  endclass

  class c02_nested_mutable;
    int NESTED_LIMIT;
    covergroup cg_nested with function sample(int value);
      cp: coverpoint value {
        bins nested_mutable = {[0:(NESTED_LIMIT + 1)]};
      }
    endgroup
  endclass

  class c03_ref_formal;
    covergroup cg_ref(ref int REF_LIMIT)
        with function sample(int value);
      cp: coverpoint value {
        bins ref_formal = {[0:REF_LIMIT]};
      }
    endgroup
  endclass

  class c04_late_order;
    const int LATE_LIMIT;
    covergroup cg_late with function sample(int value);
      cp: coverpoint value {
        bins late_order = {[0:LATE_LIMIT]};
      }
    endgroup
    function new;
      cg_late = new;
      LATE_LIMIT = 3;
    endfunction
  endclass

  class c05_conditional_order;
    const int CONDITIONAL_LIMIT;
    covergroup cg_conditional with function sample(int value);
      cp: coverpoint value {
        bins conditional_order = {[0:CONDITIONAL_LIMIT]};
      }
    endgroup
    function new(bit take_initializer);
      if (take_initializer)
        CONDITIONAL_LIMIT = 4;
      cg_conditional = new;
    endfunction
  endclass

  class c06_same_loop;
    const int LOOP_LIMIT;
    covergroup cg_loop with function sample(int value);
      cp: coverpoint value {
        bins same_loop = {[0:LOOP_LIMIT]};
      }
    endgroup
    function new;
      repeat (1) begin
        LOOP_LIMIT = 5;
        cg_loop = new;
      end
    endfunction
  endclass

  class c07_same_join_none;
    const int FORK_LIMIT;
    covergroup cg_fork with function sample(int value);
      cp: coverpoint value {
        bins same_join_none = {[0:FORK_LIMIT]};
      }
    endgroup
    function new;
      fork
        begin
          FORK_LIMIT = 6;
          cg_fork = new;
        end
      join_none
    endfunction
  endclass

  class c08a_local_base;
    local const int LOCAL_LIMIT = 7;
  endclass

  class c08b_base_local_visibility extends c08a_local_base;
    covergroup cg_base_local with function sample(int value);
      cp: coverpoint value {
        bins base_local = {[0:LOCAL_LIMIT]};
      }
    endgroup
  endclass

  class c09_static_const_missing;
    static const int STATIC_LIMIT;
    covergroup cg_static_missing with function sample(int value);
      cp: coverpoint value {
        bins static_missing = {[0:STATIC_LIMIT]};
      }
    endgroup
  endclass

  class c10_straight_reassignment;
    const int DUPLICATE_LIMIT;
    function new;
      DUPLICATE_LIMIT = 1;
      DUPLICATE_LIMIT = 2;
    endfunction
  endclass

  class c11_repeat_local_shadow #(int N = 1);
    const int SHADOWED_REPEAT_LIMIT;
    covergroup cg_repeat_shadow with function sample(int value);
      cp: coverpoint value {
        bins shadowed_repeat = {[0:SHADOWED_REPEAT_LIMIT]};
      }
    endgroup
    function new;
      begin
        int N = 0;
        repeat (N)
          SHADOWED_REPEAT_LIMIT = 8;
      end
      cg_repeat_shadow = new;
    endfunction
  endclass

  class c12_repeat_formal_shadow #(int N = 1);
    const int FORMAL_REPEAT_LIMIT;
    covergroup cg_repeat_formal with function sample(int value);
      cp: coverpoint value {
        bins formal_repeat = {[0:FORMAL_REPEAT_LIMIT]};
      }
    endgroup
    function new(int N);
      repeat (N)
        FORMAL_REPEAT_LIMIT = 9;
      cg_repeat_formal = new;
    endfunction
  endclass

  class c13_repeat_parameter_zero #(int N = 0);
    const int ZERO_REPEAT_LIMIT;
    covergroup cg_repeat_zero with function sample(int value);
      cp: coverpoint value {
        bins zero_repeat = {[0:ZERO_REPEAT_LIMIT]};
      }
    endgroup
    function new;
      repeat (N)
        ZERO_REPEAT_LIMIT = 10;
      cg_repeat_zero = new;
    endfunction
  endclass

  class c14_for_step_same_loop;
    const int STEP_LIMIT;
    covergroup cg_for_step with function sample(int value);
      cp: coverpoint value {
        bins for_step = {[0:STEP_LIMIT]};
      }
    endgroup
    function new(bit enter);
      // The body and step are both in the repeated loop region. The
      // initializer and referring constructor may not appear together there.
      for (; enter; STEP_LIMIT = 11) begin
        cg_for_step = new;
        enter = 0;
      end
    endfunction
  endclass

endmodule
