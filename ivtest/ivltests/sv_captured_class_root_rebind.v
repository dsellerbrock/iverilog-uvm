class root_item;
  int value;
  int other;
  int data[];
endclass
module sv_captured_class_root_rebind;
  root_item h, original, replacement;
  int value_events, other_events;
  function automatic int rebind();
    h = replacement;
    return 7;
  endfunction
  function automatic int clear_handle();
    h = null;
    return 1;
  endfunction
  function automatic int rebind_ref(ref root_item target, input root_item next_value);
    target = next_value;
    return 7;
  endfunction
  task automatic automatic_context();
    root_item local_h, retained, next_value;
    local_h = new;
    local_h.value = 7;
    retained = local_h;
    next_value = new;
    next_value.value = 100;
    local_h.value += rebind_ref(local_h, next_value);
    if (retained.value != 14 || local_h != next_value || local_h.value != 100)
      $fatal(1, "automatic root rebinding");
  endtask
  initial begin
    h = new;
    h.value = 7;
    original = h;
    replacement = new;
    replacement.value = 100;
    fork
      forever begin @(original.value); value_events++; end
      forever begin @(original.other); other_events++; end
    join_none
    #1;
    h.value += rebind();
    #1;
    if (original.value != 14 || h != replacement || h.value != 100)
      $fatal(1, "rebound root overwritten");
    if (value_events != 1 || other_events != 0)
      $fatal(1, "retained alias/property event filtering");
    h = original;
    h.value += clear_handle();
    #1;
    if (h != null || original.value != 15 || value_events != 2 || other_events != 0)
      $fatal(1, "null rebind or alias event");
    h = original;
    h.value += 1;
    #1;
    if (h != original || original.value != 16 || value_events != 3)
      $fatal(1, "unchanged root mutation");
    h.value += 0;
    #1;
    if (value_events != 3 || other_events != 0)
      $fatal(1, "same value or unrelated field event");
    original.data = new[1];
    original.data[0] = 20;
    h.data[0] = rebind();
    if (original.data[0] != 7 || h != replacement || h.value != 100)
      $fatal(1, "captured container root");
    automatic_context();
    disable fork;
    $display("PASSED");
  end
endmodule
