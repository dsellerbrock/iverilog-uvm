// IEEE 1800-2017/2023 7.10.5: writes to a bounded queue discard elements
// beyond the declared maximum index. Pin destination bounds across same-kind
// subroutine copy, aggregate, nested-container, and associative-value stores.
typedef real bounded_real_queue_2_t[$:1];

typedef struct {
  bounded_real_queue_2_t q;
  real d[];
} bounded_container_aggregate_t;

module sv_bounded_queue_same_kind_contexts;
  int errors;
  int call_result;
  real oversized_q[$];
  real dynamic_source[];
  bounded_real_queue_2_t output_q;
  bounded_real_queue_2_t inout_q;
  bounded_real_queue_2_t nested_q[$];
  bounded_real_queue_2_t explicit_by_key[int];
  bounded_real_queue_2_t default_by_key[int];
  bounded_container_aggregate_t aggregate_value;

  task check(input bit condition, input string what);
    if (!condition) begin
      errors++;
      $display("FAILED: %s", what);
    end
  endtask

  function automatic int inspect_bounded_input(input bounded_real_queue_2_t q);
    return q.size() == 2 && q[0] == 2.0 && q[1] == 3.0;
  endfunction

  function automatic int make_oversized_output(output real q[$]);
    q = '{5.0, 7.0, 11.0, 13.0};
    return q.size();
  endfunction

  function automatic int grow_oversized_inout(inout real q[$]);
    int initial_size = q.size();
    q.push_back(17.0);
    q.push_back(19.0);
    return initial_size;
  endfunction

  initial begin
    oversized_q = '{2.0, 3.0, 5.0, 7.0};
    dynamic_source = new[3];
    dynamic_source[0] = 23.0;
    dynamic_source[1] = 29.0;
    dynamic_source[2] = 31.0;

    check(inspect_bounded_input(oversized_q),
          "bounded function input truncates oversized queue actual");

    call_result = make_oversized_output(output_q);
    check(call_result == 4 && output_q.size() == 2
          && output_q[0] == 5.0 && output_q[1] == 7.0,
          "bounded function output actual truncates copy-out");

    inout_q = '{37.0, 41.0};
    call_result = grow_oversized_inout(inout_q);
    check(call_result == 2 && inout_q.size() == 2
          && inout_q[0] == 37.0 && inout_q[1] == 41.0,
          "bounded function inout actual truncates copy-out");

    aggregate_value = '{oversized_q, dynamic_source};
    oversized_q[0] = 43.0;
    dynamic_source[0] = 47.0;
    aggregate_value.d[1] = 53.0;
    check(aggregate_value.q.size() == 2
          && aggregate_value.q[0] == 2.0 && aggregate_value.q[1] == 3.0,
          "bounded aggregate queue member truncates and copies value");
    check(aggregate_value.d.size() == 3
          && aggregate_value.d[0] == 23.0
          && aggregate_value.d[1] == 53.0
          && dynamic_source[1] == 29.0,
          "same-kind aggregate dynamic-array member does not alias source");

    nested_q = '{oversized_q};
    check(nested_q.size() == 1 && nested_q[0].size() == 2
          && nested_q[0][0] == 43.0 && nested_q[0][1] == 3.0,
          "bounded nested queue element truncates oversized source");

    explicit_by_key = '{7: oversized_q};
    oversized_q[1] = 59.0;
    check(explicit_by_key[7].size() == 2
          && explicit_by_key[7][0] == 43.0
          && explicit_by_key[7][1] == 3.0,
          "bounded explicit associative value truncates and copies source");

    default_by_key = '{default: oversized_q};
    default_by_key[9].push_back(61.0);
    check(default_by_key[9].size() == 2
          && default_by_key[9][0] == 43.0
          && default_by_key[9][1] == 59.0,
          "bounded default associative value truncates oversized source");

    if (errors == 0)
      $display("PASSED");
    else
      $fatal(1, "FAILED -- %0d mismatches", errors);
  end
endmodule
