// IEEE 1800-2017/2023 §§7.4.2, 7.5, 7.8, and 7.10: a fixed unpacked
// array element may itself be a dynamic array, associative array, or queue;
// selecting the fixed word leaves the contained runtime container semantics.
module sv_fixed_container_array_elements;
  typedef int queue_bound_1_t[$:1];
  typedef int queue_bound_3_t[$:3];
  typedef int int_darray_t[];
  typedef int int_assoc_t[int];
  typedef queue_bound_1_t queue_darray_t[];
  typedef queue_bound_1_t queue_assoc_t[int];

  queue_bound_1_t fixed_queue[1:0];
  int_darray_t fixed_darray[0:0];
  int_assoc_t fixed_assoc[0:0];
  queue_darray_t fixed_nested_darray[0:0];
  queue_assoc_t fixed_nested_assoc[0:0];
  queue_bound_3_t wider_source;

  int slot_calls;
  function automatic int selected_slot();
    slot_calls += 1;
    return 1;
  endfunction

  initial begin
    // A selected fixed slot is the queue receiver, not queue element 1.
    fixed_queue[selected_slot()].push_back(11);
    if (slot_calls != 1)
      $fatal(1, "task-method fixed index evaluated more than once");
    if (fixed_queue[selected_slot()].size() != 1)
      $fatal(1, "function-method receiver did not select fixed queue slot");
    if (slot_calls != 2)
      $fatal(1, "function-method fixed index evaluated more than once");

    // Reads and writes retain the fixed-slot and runtime-container ranks.
    fixed_queue[1][0] = 12;
    if (fixed_queue[1][0] != 12)
      $fatal(1, "fixed queue element read/write lost a rank");

    wider_source.push_back(21);
    wider_source.push_back(22);
    wider_source.push_back(23);
    fixed_queue[0] = wider_source;
    if (fixed_queue[0].size() != 2 || fixed_queue[0][0] != 21
        || fixed_queue[0][1] != 22)
      $fatal(1, "whole queue slot assignment lost destination bound");

    fixed_darray[0] = new[2];
    fixed_darray[0][1] = 31;
    if (fixed_darray[0].size() != 2 || fixed_darray[0][1] != 31)
      $fatal(1, "fixed dynamic-array slot was not independently addressable");

    fixed_assoc[0][7] = 41;
    if (!fixed_assoc[0].exists(7) || fixed_assoc[0][7] != 41)
      $fatal(1, "fixed associative-array slot was not independently addressable");

    // The fixed word may itself hold a recursive Q/D/A carrier.
    fixed_nested_darray[0] = new[1];
    fixed_nested_darray[0][0].push_back(51);
    if (fixed_nested_darray[0][0].size() != 1
        || fixed_nested_darray[0][0][0] != 51)
      $fatal(1, "fixed dynamic-array slot lost its nested queue");

    fixed_nested_assoc[0][9].push_back(61);
    if (fixed_nested_assoc[0][9].size() != 1
        || fixed_nested_assoc[0][9][0] != 61)
      $fatal(1, "fixed associative-array slot lost its nested queue");

    $display("PASSED");
  end
endmodule
