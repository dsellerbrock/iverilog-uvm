// IEEE 1800-2017/2023 18.6.2, 18.8 and 18.11.
class callback_key;
  int pre_calls;
  function void pre_randomize(); pre_calls++; endfunction
endclass
class callback_leaf;
  rand bit value;
  int pre_calls, post_calls;
  constraint c { value == 1; }
  function void pre_randomize(); pre_calls++; endfunction
  function void post_randomize(); post_calls++; endfunction
endclass
class callback_containers;
  rand callback_leaf fixed_values[2];
  rand callback_leaf dynamic_values[];
  rand callback_leaf queue_values[$];
  rand callback_leaf integer_values[int];
  rand callback_leaf string_values[string];
  rand callback_leaf object_values[callback_key];
endclass
typedef struct {
  rand logic [31:0] value;
  int state_value;
} callback_struct_t;
class nested_callback_containers;
  rand callback_leaf nested[int][];
  rand callback_struct_t structs[int];
endclass
module main;
  callback_containers root = new;
  callback_leaf active[6], inactive[6];
  callback_key k0 = new, k1 = new;
  nested_callback_containers nested_root = new;
  callback_leaf nested_child = new, row[];
  callback_struct_t entry;
  initial begin
    foreach (active[i]) begin active[i] = new; inactive[i] = new; end
    root.fixed_values[0] = active[0]; root.fixed_values[1] = inactive[0];
    root.dynamic_values = new[2];
    root.dynamic_values = '{active[1], inactive[1]};
    root.queue_values = '{active[2], inactive[2]};
    root.integer_values[0] = active[3]; root.integer_values[1] = inactive[3];
    root.string_values["go"] = active[4]; root.string_values["hold"] = inactive[4];
    root.object_values[k0] = active[5]; root.object_values[k1] = inactive[5];
    root.fixed_values[1].rand_mode(0);
    root.dynamic_values[1].rand_mode(0);
    root.queue_values[1].rand_mode(0);
    root.integer_values[1].rand_mode(0);
    root.string_values["hold"].rand_mode(0);
    root.object_values[k1].rand_mode(0);
    if (!root.randomize()) $fatal(1, "container solve failed");
    foreach (active[i]) begin
      if (active[i].pre_calls != 1 || active[i].post_calls != 1 || active[i].value != 1)
        $fatal(1, "active container member %0d missed callback or solve", i);
      if (inactive[i].pre_calls != 0 || inactive[i].post_calls != 0 || inactive[i].value != 0)
        $fatal(1, "disabled container member %0d participated", i);
    end
    if (!root.randomize(fixed_values, dynamic_values, queue_values,
                        integer_values, string_values, object_values))
      $fatal(1, "explicit container selection failed");
    foreach (active[i]) begin
      if (active[i].pre_calls != 2 || active[i].post_calls != 2
          || inactive[i].pre_calls != 1 || inactive[i].post_calls != 1
          || inactive[i].value != 1)
        $fatal(1, "explicit selection failed for container %0d", i);
    end
    if (k0.pre_calls != 0 || k1.pre_calls != 0)
      $fatal(1, "associative keys were treated as random members");
    row = new[1];
    row[0] = nested_child;
    nested_root.nested[7] = row;
    entry.value = 'x;
    entry.state_value = 42;
    nested_root.structs[9] = entry;
    if (!nested_root.randomize()) $fatal(1, "nested associative solve failed");
    entry = nested_root.structs[9];
    if (nested_child.value != 1 || nested_child.pre_calls != 1
        || nested_child.post_calls != 1)
      $fatal(1, "nested associative leaf skipped");
    if ((^entry.value) === 1'bx || entry.state_value != 42)
      $fatal(1, "associative struct random or state field mishandled");
    $display("PASSED");
  end
endmodule
