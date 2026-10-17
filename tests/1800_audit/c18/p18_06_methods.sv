module top;
  int fails = 0;
  task automatic chk(string id, bit ok);
    if (ok) $display("PASS %s", id);
    else begin $display("FAIL %s", id); fails++; end
  endtask

  class Basic;
    rand bit [3:0] value;
    constraint range_c { value >= 4; value <= 9; }
  endclass
  class Derived extends Basic;
    constraint derived_c { value == 7; }
  endclass

  class HookBase;
    int pre_calls = 0;
    int post_calls = 0;
    function void pre_randomize(); pre_calls++; endfunction
    function void post_randomize(); post_calls++; endfunction
  endclass
  class HookInherited extends HookBase;
    rand bit value;
    constraint value_c { value == 1; }
  endclass
  class HookOverride extends HookBase;
    int own_pre_calls = 0;
    int own_post_calls = 0;
    rand bit value;
    function void pre_randomize(); own_pre_calls++; endfunction
    function void post_randomize(); own_post_calls++; endfunction
  endclass

  class Impossible;
    rand int value;
    int post_calls = 0;
    constraint impossible_c { value == 1; value == 2; }
    function void post_randomize(); post_calls++; endfunction
  endclass

  class CallbackChild;
    rand bit value;
    int pre_calls = 0;
    int post_calls = 0;
    function void pre_randomize(); pre_calls++; endfunction
    function void post_randomize(); post_calls++; endfunction
  endclass
  class CallbackParent;
    rand CallbackChild rand_child;
    CallbackChild plain_child;
    function new(); rand_child = new; plain_child = new; endfunction
  endclass

  class SharedRandom;
    static rand int shared;
    constraint shared_c { shared == 11; }
  endclass

  Basic base_handle;
  Derived derived;
  HookInherited inherited;
  HookOverride overridden;
  Impossible impossible;
  CallbackParent parent_enabled, parent_disabled;
  SharedRandom shared_a, shared_b;
  int ok;
  initial begin
    derived = new; base_handle = derived;
    ok = base_handle.randomize();
    chk("18.6.randomize_success_and_constraint", ok == 1 && base_handle.value >= 4 && base_handle.value <= 9);
    chk("18.6.virtual_randomize_uses_derived_constraint", base_handle.value == 7);

    inherited = new;
    ok = inherited.randomize();
    chk("18.6.inherited_pre_post", ok && inherited.pre_calls == 1 && inherited.post_calls == 1);
    overridden = new;
    ok = overridden.randomize();
    chk("18.6.override_without_super_skips_base", ok && overridden.own_pre_calls == 1
        && overridden.own_post_calls == 1 && overridden.pre_calls == 0 && overridden.post_calls == 0);

    impossible = new; impossible.value = 7;
    ok = impossible.randomize();
    chk("18.6.failure_retains_values_and_skips_post", !ok && impossible.value == 7
        && impossible.post_calls == 0);

    parent_enabled = new;
    ok = parent_enabled.randomize();
    chk("18.6.enabled_rand_object_callbacks", ok && parent_enabled.rand_child.pre_calls == 1
        && parent_enabled.rand_child.post_calls == 1);
    chk("18.6.nonrand_object_callbacks_skipped", parent_enabled.plain_child.pre_calls == 0
        && parent_enabled.plain_child.post_calls == 0);
    parent_disabled = new; parent_disabled.rand_mode(0);
    ok = parent_disabled.randomize();
    chk("18.6.rand_mode_zero_object_callbacks_skipped", ok
        && parent_disabled.rand_child.pre_calls == 0 && parent_disabled.rand_child.post_calls == 0);

    shared_a = new; shared_b = new;
    ok = shared_a.randomize();
    chk("18.6.static_rand_shared_across_instances", ok && shared_a.shared == 11
        && shared_b.shared == 11 && SharedRandom::shared == 11);

    if (fails) $fatal(1, "DONE fails=%0d", fails);
    $display("DONE fails=0");
    $finish;
  end
endmodule
