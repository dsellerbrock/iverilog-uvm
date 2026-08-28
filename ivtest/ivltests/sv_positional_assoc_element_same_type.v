// IEEE 1800-2017/2023 7.6, 7.8, 13.4.2 and 13.5: positional
// queue/dynamic-array conversions retain the complete type of an associative-
// array element, including its key metadata, and copy nested maps by value.
typedef int same_assoc_inner_t[string];
typedef same_assoc_inner_t same_assoc_queue_t[$];
typedef same_assoc_inner_t same_assoc_darray_t[];

module sv_positional_assoc_element_same_type;
  int errors;
  int result;
  same_assoc_inner_t queue_item;
  same_assoc_inner_t empty_item;
  same_assoc_inner_t popped_item;
  same_assoc_queue_t source_queue;
  same_assoc_queue_t function_actual;
  same_assoc_darray_t source_darray;
  same_assoc_darray_t cast_darray;

  function automatic int make_darray(output same_assoc_inner_t value[]);
    value = new[1];
    value[0]["function"] = 31;
    return value.size();
  endfunction

  initial begin
    queue_item["queue"] = 11;
    source_queue.push_back(queue_item);
    source_darray = new[1];
    source_darray[0]["darray"] = 17;

    cast_darray = same_assoc_darray_t'(source_queue);
    popped_item = same_assoc_queue_t'(source_darray).pop_front();
    source_queue[0]["queue"] = 13;
    source_darray[0]["darray"] = 19;

    if (cast_darray.size() != 1
        || cast_darray[0]["queue"] != 11
        || popped_item["darray"] != 17) begin
      errors++;
      $display("FAILED: same-type nested-assoc cast value or isolation");
    end

    result = make_darray(function_actual);
    function_actual.push_back(empty_item);
    if (result != 1 || function_actual.size() != 2
        || function_actual[0]["function"] != 31) begin
      errors++;
      $display("FAILED: same-type nested-assoc function output copyback");
    end

    function_actual[0]["function"] = 37;
    if (cast_darray[0]["queue"] != 11
        || popped_item["darray"] != 17
        || function_actual[0]["function"] != 37) begin
      errors++;
      $display("FAILED: nested associative values did not copy independently");
    end

    if (errors == 0)
      $display("PASSED");
    else
      $fatal(1, "FAILED -- %0d mismatches", errors);
  end
endmodule
