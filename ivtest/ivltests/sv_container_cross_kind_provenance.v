// IEEE 1800-2017/2023 7.6 and 13.5.1: equivalent-element queue and dynamic-
// array values are copied into the destination's declared container kind,
// including expression results and pass-by-value subroutine arguments.
class cross_kind_provenance_box;
  real queue_by_key[int][$];
  real queue_slots[$][$];
  real darray_slots[][$];
endclass

module sv_container_cross_kind_provenance;
  typedef real darray_t[];
  typedef real queue_t[$];

  int errors;
  int output_result;
  bit choose;
  cross_kind_provenance_box box;
  queue_t q0;
  queue_t q1;
  darray_t from_property;
  darray_t from_conditional;
  darray_t from_function;

  task check(input bit condition, input string what);
    if (!condition) begin
      errors++;
      $display("FAILED: %s", what);
    end
  endtask

  task automatic check_task_input(input real d[]);
    check(d.size() == 2 && d[0] == 2.0 && d[1] == 3.0,
          "task input copies selected associative property value");
    // A dynamic array cannot grow by assigning index == size. A leaked queue
    // object would append this value and make the task-local size three.
    d[d.size()] = 91.0;
    check(d.size() == 2,
          "task input materializes its declared dynamic-array kind");
  endtask

  function automatic queue_t return_queue();
    return_queue = '{11.0, 13.0};
  endfunction

  function automatic int make_darray(output real d[]);
    d = new[2];
    d[0] = 23.0;
    d[1] = 29.0;
    return d.size();
  endfunction

  initial begin
    box = new;
    q0 = '{2.0, 3.0};
    q1 = '{5.0, 7.0};
    box.queue_by_key[7] = q0;

    check_task_input(box.queue_by_key[7]);
    check(box.queue_by_key[7].size() == 2
          && box.queue_by_key[7][0] == 2.0
          && box.queue_by_key[7][1] == 3.0,
          "task input preserves source value isolation");

    from_property = box.queue_by_key[7];
    box.queue_by_key[7][0] = 17.0;
    from_property[from_property.size()] = 101.0;
    check(from_property.size() == 2
          && from_property[0] == 2.0 && from_property[1] == 3.0,
          "selected associative property converts to independent darray");

    choose = 1'b1;
    from_conditional = choose ? q0 : q1;
    q0[0] = 19.0;
    from_conditional[from_conditional.size()] = 103.0;
    check(from_conditional.size() == 2
          && from_conditional[0] == 2.0 && from_conditional[1] == 3.0,
          "conditional queue result converts to independent darray");

    from_function = return_queue();
    from_function[from_function.size()] = 107.0;
    check(from_function.size() == 2
          && from_function[0] == 11.0 && from_function[1] == 13.0,
          "queue-returning function result converts to darray");

    // Output copy-out is another destination-typed boundary. Both selected
    // positional properties are queue leaves even though the function formal
    // is a dynamic array; the outer property kind must not change that leaf.
    box.queue_slots.push_back(q1);
    box.darray_slots = new[1];
    box.darray_slots[0] = q1;
    output_result = make_darray(box.queue_slots[0]);
    box.queue_slots[0].push_back(31.0);
    output_result = make_darray(box.darray_slots[0]);
    box.darray_slots[0].push_back(37.0);
    check(output_result == 2
          && box.queue_slots[0].size() == 3
          && box.queue_slots[0][0] == 23.0
          && box.queue_slots[0][2] == 31.0,
          "function output copies into selected queue-property leaf");
    check(box.darray_slots[0].size() == 3
          && box.darray_slots[0][0] == 23.0
          && box.darray_slots[0][2] == 37.0,
          "function output copies into selected darray-property leaf");

    if (errors == 0)
      $display("PASSED");
    else
      $fatal(1, "FAILED -- %0d mismatches", errors);
  end
endmodule
