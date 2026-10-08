class holder;
  int value;
endclass

module sv_ref_static_auto_actual_fail_2023;
  int global_value;
  int dynamic_values[];
  holder object_handle;

  task automatic update(ref static int value);
    value = value + 1;
  endtask

  task automatic caller();
    automatic int local_value;
    update(local_value);
    update(object_handle.value);
    update(dynamic_values[0]);
  endtask

  initial begin
    dynamic_values = new[1];
    object_handle = new;
    caller();
  end
endmodule
