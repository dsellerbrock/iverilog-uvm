// IEEE 1800-2017/2023 7.6 and 10.10: equivalent-element queue/dynamic-array
// values retain the destination's declared container kind through patterns,
// nested stores, queue methods, and subroutine value arguments.
typedef struct {
  real q[$];
} cross_kind_struct_t;

class cross_kind_handle_item;
  int value;
endclass

class cross_kind_context_box;
  real q[$];
  real q_by_key[int][$];
  real fixed_q[0:0][$];
endclass

module sv_container_cross_kind_contexts;
  int errors;
  int output_call_result;
  real source_d[];
  real source_d2[];
  real method_q[$][$];
  real deep_by_key[int][int][$];
  real pattern_by_key[int][$];
  real pattern_q[$][$];
  real splice_source[][];
  real splice_q[$][$];
  real slice_source[][];
  real slice_q[$][];
  real slice_keep[];
  real slice_replace[];
  real output_q[$];
  real reverse_function_output_d[];
  real task_output_q[$];
  real task_output_d[];
  real function_inout_d[];
  real function_inout_q[$];
  real automatic_empty_q[$];
  real static_output_q_first[$];
  real static_output_q_second[$];
  cross_kind_handle_item handle_source_d[];
  cross_kind_handle_item handle_pattern_q[$][$];
  cross_kind_handle_item shared_handle;
  cross_kind_handle_item replacement_handle;
  cross_kind_struct_t aggregate_value;
  cross_kind_context_box box;

  task check(input bit condition, input string what);
    if (!condition) begin
      errors++;
      $display("FAILED: %s", what);
    end
  endtask

  function automatic int queue_input_size(input real q[$]);
    q.push_back(19.0);
    return q.size();
  endfunction

  function automatic void make_darray(output real d[]);
    d = new[2];
    d[0] = 23.0;
    d[1] = 29.0;
  endfunction

  function automatic int make_queue(output real q[$]);
    q.push_back(79.0);
    q.push_back(83.0);
    return q.size();
  endfunction

  function automatic int append_queue_inout(inout real q[$]);
    int initial_size = q.size();
    q.push_back(97.0);
    return initial_size;
  endfunction

  function automatic int grow_darray_inout(inout real d[]);
    int initial_size = d.size();
    d = new[initial_size + 1](d);
    d[initial_size] = 101.0;
    return initial_size;
  endfunction

  task automatic task_make_darray(output real d[]);
    d = new[2];
    d[0] = 103.0;
    d[1] = 107.0;
  endtask

  task automatic task_make_queue(output real q[$]);
    q.push_back(109.0);
    q.push_back(113.0);
  endtask

  function automatic int leave_queue_default(output real q[$]);
    return 1;
  endfunction

  function int retain_static_queue(output real q[$], input bit write_value);
    if (write_value) begin
      q.delete();
      q.push_back(73.0);
    end
    return 1;
  endfunction

  initial begin
    source_d = new[2];
    source_d[0] = 2.0;
    source_d[1] = 3.0;
    source_d2 = new[1];
    source_d2[0] = 5.0;

    // Each queue method stores one whole dynamic array as a queue-valued
    // element. The subsequent queue-only mutation is the runtime-kind oracle.
    method_q.push_back(source_d);
    method_q.push_front(source_d2);
    method_q.insert(1, source_d2);
    method_q[0].push_back(7.0);
    method_q[1].push_back(11.0);
    method_q[2].push_back(13.0);
    check(method_q.size() == 3
          && method_q[0].size() == 2 && method_q[0][1] == 7.0
          && method_q[1].size() == 2 && method_q[1][1] == 11.0
          && method_q[2].size() == 3 && method_q[2][2] == 13.0,
          "push/insert materialize queue-valued elements");

    deep_by_key[1][2] = source_d;
    deep_by_key[1][2][2] = 17.0;
    check(deep_by_key[1][2][0] == 2.0
          && deep_by_key[1][2][1] == 3.0
          && deep_by_key[1][2][2] == 17.0,
          "deep associative store keeps queue kind");

    pattern_by_key = '{7: source_d};
    pattern_by_key[7].push_back(31.0);
    check(pattern_by_key[7].size() == 3
          && pattern_by_key[7][2] == 31.0,
          "explicit associative pattern queue value");
    pattern_by_key = '{default: source_d2};
    pattern_by_key[9].push_back(37.0);
    check(pattern_by_key[9].size() == 2
          && pattern_by_key[9][1] == 37.0,
          "default associative pattern queue value");

    pattern_q = '{source_d};
    pattern_q[0].push_back(41.0);
    check(pattern_q.size() == 1 && pattern_q[0].size() == 3
          && pattern_q[0][2] == 41.0,
          "single container pattern item keeps queue kind");

    shared_handle = new;
    shared_handle.value = 73;
    handle_source_d = new[1];
    handle_source_d[0] = shared_handle;
    handle_pattern_q = '{handle_source_d};
    shared_handle.value = 79;
    check(handle_pattern_q.size() == 1
          && handle_pattern_q[0].size() == 1
          && handle_pattern_q[0][0] == shared_handle
          && handle_source_d[0] == shared_handle
          && handle_source_d[0].value == 79,
          "container conversion preserves class-handle identity");
    replacement_handle = new;
    replacement_handle.value = 83;
    handle_source_d = new[2](handle_source_d);
    handle_source_d[0] = replacement_handle;
    check(handle_pattern_q[0].size() == 1
          && handle_source_d.size() == 2
          && handle_pattern_q[0][0] == shared_handle
          && handle_pattern_q[0][0].value == 79
          && handle_source_d[0] == replacement_handle,
          "container conversion copies class-handle slots by value");

    splice_source = new[2];
    splice_source[0] = source_d;
    splice_source[1] = source_d2;
    splice_q = {splice_source};
    splice_q[0].push_back(43.0);
    splice_q[1].push_back(47.0);
    check(splice_q.size() == 2
          && splice_q[0].size() == 3 && splice_q[0][2] == 43.0
          && splice_q[1].size() == 2 && splice_q[1][1] == 47.0,
          "collection splice converts every inner queue value");

    // IEEE 1800-2017/2023 7.6: a queue slice is assignment-compatible with
    // a dynamic array whose element type is equivalent. The outer conversion
    // must not reject container-valued elements or alias their storage.
    slice_keep = new[1];
    slice_keep[0] = 89.0;
    slice_replace = new[2];
    slice_replace[0] = 97.0;
    slice_replace[1] = 101.0;
    slice_q.push_back(slice_keep);
    slice_q.push_back(slice_keep);
    slice_source = new[1];
    slice_source[0] = slice_replace;
    slice_q[1:$] = slice_source;
    slice_source[0][0] = 103.0;
    check(slice_q.size() == 2
          && slice_q[0].size() == 1 && slice_q[0][0] == 89.0
          && slice_q[1].size() == 2
          && slice_q[1][0] == 97.0 && slice_q[1][1] == 101.0,
          "queue suffix slice converts outer darray and copies inner values");

    aggregate_value = '{source_d};
    aggregate_value.q.push_back(53.0);
    check(aggregate_value.q.size() == 3
          && aggregate_value.q[2] == 53.0,
          "aggregate pattern member keeps queue kind");

    check(queue_input_size(source_d) == 3 && source_d.size() == 2,
          "input formal queue kind and value isolation");
    make_darray(output_q);
    output_q.push_back(59.0);
    check(output_q.size() == 3 && output_q[0] == 23.0
          && output_q[2] == 59.0,
          "direct output copy-back keeps queue kind");

    // Exercise the reverse function-output direction without a queue
    // destination that could repair a wrongly materialized temporary. The
    // out-of-range write is a legal no-op only for the dynamic-array actual.
    reverse_function_output_d = new[1];
    reverse_function_output_d[0] = -1.0;
    output_call_result = make_queue(reverse_function_output_d);
    reverse_function_output_d[reverse_function_output_d.size()] = 127.0;
    check(output_call_result == 2
          && reverse_function_output_d.size() == 2
          && reverse_function_output_d[0] == 79.0
          && reverse_function_output_d[1] == 83.0,
          "queue function output copies back as dynamic-array actual kind");

    // Task copy-out uses a distinct frontend/lowering path. Pin both cross-kind
    // directions and then use an operation unique to the caller's declared
    // destination kind.
    task_make_darray(task_output_q);
    task_output_q.push_back(127.0);
    check(task_output_q.size() == 3
          && task_output_q[0] == 103.0 && task_output_q[2] == 127.0,
          "darray task output copies back as queue actual kind");
    task_make_queue(task_output_d);
    task_output_d[task_output_d.size()] = 127.0;
    check(task_output_d.size() == 2
          && task_output_d[0] == 109.0 && task_output_d[1] == 113.0,
          "queue task output copies back as dynamic-array actual kind");

    // Inout has both copy-in and copy-out semantics. Each call converts in one
    // direction on entry and the opposite direction on return.
    function_inout_d = new[2];
    function_inout_d[0] = 131.0;
    function_inout_d[1] = 137.0;
    output_call_result = append_queue_inout(function_inout_d);
    function_inout_d[function_inout_d.size()] = 127.0;
    check(output_call_result == 2 && function_inout_d.size() == 3
          && function_inout_d[0] == 131.0
          && function_inout_d[2] == 97.0,
          "queue inout formal round-trips through dynamic-array actual kind");

    function_inout_q.push_back(139.0);
    function_inout_q.push_back(149.0);
    output_call_result = grow_darray_inout(function_inout_q);
    function_inout_q.push_back(151.0);
    check(output_call_result == 2 && function_inout_q.size() == 4
          && function_inout_q[0] == 139.0
          && function_inout_q[2] == 101.0
          && function_inout_q[3] == 151.0,
          "darray inout formal round-trips through queue actual kind");

    // IEEE 1800-2017/2023 13.4.2: automatic output storage receives its
    // declared default on every call, while a static function retains its
    // formal storage between calls. Neither output argument copies in the
    // caller's existing queue value.
    automatic_empty_q.push_back(69.0);
    output_call_result = leave_queue_default(automatic_empty_q);
    check(automatic_empty_q.size() == 0,
          "automatic queue output starts at its empty default");
    output_call_result = retain_static_queue(static_output_q_first, 1'b1);
    static_output_q_first[0] = 79.0;
    static_output_q_second.push_back(83.0);
    output_call_result = retain_static_queue(static_output_q_second, 1'b0);
    check(static_output_q_first[0] == 79.0
          && static_output_q_second.size() == 1
          && static_output_q_second[0] == 73.0,
          "static queue output retains independent formal storage");

    box = new;
    make_darray(box.q);
    box.q.push_back(61.0);
    make_darray(box.q_by_key[4]);
    box.q_by_key[4].push_back(67.0);
    check(box.q.size() == 3 && box.q[2] == 61.0
          && box.q_by_key[4].size() == 3
          && box.q_by_key[4][2] == 67.0,
          "property output copy-back keeps queue kinds");

    make_darray(box.fixed_q[0]);
    box.fixed_q[0].push_back(71.0);
    check(box.fixed_q[0].size() == 3
          && box.fixed_q[0][2] == 71.0,
          "fixed-slot output copy-back keeps queue kind");

    if (errors == 0)
      $display("PASSED");
    else
      $fatal(1, "FAILED -- %0d mismatches", errors);
  end
endmodule
