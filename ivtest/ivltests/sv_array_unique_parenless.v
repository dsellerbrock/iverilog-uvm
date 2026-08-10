// IEEE 1800-2017 7.12/7.12.1: unique and unique_index are queue-valued
// locator methods. Their iterator parentheses may be omitted, and discarding
// a result does not mutate the receiver.
module main;
  typedef int int_queue_t[$];

  typedef struct {
    int unique_index;
  } member_t;

  int values[];
  int empty[];
  int never_allocated[];
  int result[$];
  int indexes[$];
  int result_da[];
  int result_fixed[3];
  int queue_values[$];
  int bounded_values[$:2];
  int statement_queue[$];
  int fixed_values[0:5];
  int fixed_descending[5:0];
  int fixed_nonzero[5:7];
  bit [39:0] wide_values[];
  bit [39:0] wide_result[$];
  int fresh_results[$][$];
  member_t member_values[];
  int scalar_result;
  int i;
  bit seen_3;
  bit seen_10;
  bit seen_20;
  bit failed;

  function automatic int_queue_t get_queue();
    get_queue = '{10, 10, 3, 20, 20, 10};
  endfunction

  task automatic check(input string label, input logic ok);
    if (ok !== 1'b1) begin
      $display("FAILED -- %0s", label);
      failed = 1'b1;
    end
  endtask

  task automatic check_values(input string label, input int got[$]);
    got.sort();
    check(label, got.size() == 3
          && got[0] == 3 && got[1] == 10 && got[2] == 20);
  endtask

  task automatic check_indexes(input string label, input int got[$]);
    seen_3 = 1'b0;
    seen_10 = 1'b0;
    seen_20 = 1'b0;
    for (i = 0; i < got.size(); i = i + 1) begin
      check("unique_index range", got[i] >= 0 && got[i] < values.size());
      if (got[i] >= 0 && got[i] < values.size()) begin
        case (values[got[i]])
          3: seen_3 = 1'b1;
          10: seen_10 = 1'b1;
          20: seen_20 = 1'b1;
          default: check("unique_index source value", 1'b0);
        endcase
      end
    end
    check(label, got.size() == 3 && seen_3 && seen_10 && seen_20);
  endtask

  task automatic check_queue_indexes(input string label, input int got[$]);
    bit got_3;
    bit got_10;
    bit got_20;
    int j;
    got_3 = 1'b0;
    got_10 = 1'b0;
    got_20 = 1'b0;
    for (j = 0; j < got.size(); j = j + 1) begin
      check("queue unique_index range",
            got[j] >= 0 && got[j] < queue_values.size());
      if (got[j] >= 0 && got[j] < queue_values.size()) begin
        case (queue_values[got[j]])
          3: got_3 = 1'b1;
          10: got_10 = 1'b1;
          20: got_20 = 1'b1;
          default: check("queue unique_index source value", 1'b0);
        endcase
      end
    end
    check(label, got.size() == 3 && got_3 && got_10 && got_20);
  endtask

  task automatic check_fixed_indexes(input string label, input int got[$]);
    bit got_3;
    bit got_10;
    bit got_20;
    int j;
    got_3 = 1'b0;
    got_10 = 1'b0;
    got_20 = 1'b0;
    for (j = 0; j < got.size(); j = j + 1) begin
      check("fixed unique_index range", got[j] >= 0 && got[j] <= 5);
      if (got[j] >= 0 && got[j] <= 5) begin
        case (fixed_values[got[j]])
          3: got_3 = 1'b1;
          10: got_10 = 1'b1;
          20: got_20 = 1'b1;
          default: check("fixed unique_index source value", 1'b0);
        endcase
      end
    end
    check(label, got.size() == 3 && got_3 && got_10 && got_20);
  endtask

  task automatic check_descending_indexes(input string label,
                                            input int got[$]);
    bit got_3;
    bit got_10;
    bit got_20;
    int j;
    got_3 = 1'b0;
    got_10 = 1'b0;
    got_20 = 1'b0;
    for (j = 0; j < got.size(); j = j + 1) begin
      check("descending fixed unique_index range",
            got[j] >= 0 && got[j] <= 5);
      if (got[j] >= 0 && got[j] <= 5) begin
        case (fixed_descending[got[j]])
          3: got_3 = 1'b1;
          10: got_10 = 1'b1;
          20: got_20 = 1'b1;
          default: check("descending fixed unique_index source value", 1'b0);
        endcase
      end
    end
    check(label, got.size() == 3 && got_3 && got_10 && got_20);
  endtask

  task automatic check_nonzero_indexes(input string label, input int got[$]);
    bit got_3;
    bit got_10;
    int j;
    got_3 = 1'b0;
    got_10 = 1'b0;
    for (j = 0; j < got.size(); j = j + 1) begin
      check("nonzero-base fixed unique_index range",
            got[j] >= 5 && got[j] <= 7);
      if (got[j] >= 5 && got[j] <= 7) begin
        case (fixed_nonzero[got[j]])
          3: got_3 = 1'b1;
          10: got_10 = 1'b1;
          default: check("nonzero-base fixed unique_index source value", 1'b0);
        endcase
      end
    end
    check(label, got.size() == 2 && got_3 && got_10);
  endtask

  task automatic check_function_indexes(input string label,
                                          input int got[$]);
    int_queue_t source;
    bit got_3;
    bit got_10;
    bit got_20;
    int j;
    source = get_queue();
    got_3 = 1'b0;
    got_10 = 1'b0;
    got_20 = 1'b0;
    for (j = 0; j < got.size(); j = j + 1) begin
      check("function-result unique_index range",
            got[j] >= 0 && got[j] < source.size());
      if (got[j] >= 0 && got[j] < source.size()) begin
        case (source[got[j]])
          3: got_3 = 1'b1;
          10: got_10 = 1'b1;
          20: got_20 = 1'b1;
          default: check("function-result unique_index source value", 1'b0);
        endcase
      end
    end
    check(label, got.size() == 3 && got_3 && got_10 && got_20);
  endtask

  initial begin
    failed = 1'b0;
    values = '{10, 10, 3, 20, 20, 10};

    result = values.unique;
    check_values("dynamic unique without parentheses", result);
    indexes = values.unique_index;
    check_indexes("dynamic unique_index without parentheses", indexes);
    check("dynamic source unchanged",
          values.size() == 6 && values[0] == 10 && values[1] == 10
          && values[2] == 3 && values[3] == 20
          && values[4] == 20 && values[5] == 10);

    result = values.unique();
    check_values("dynamic unique call control", result);
    indexes = values.unique_index();
    check_indexes("dynamic unique_index call control", indexes);

    result = get_queue().unique();
    check_values("function-result unique call", result);
    indexes = get_queue().unique_index();
    check_function_indexes("function-result unique_index call", indexes);
    result = get_queue().unique;
    check_values("function-result parenless unique", result);
    indexes = get_queue().unique_index;
    check_function_indexes("function-result parenless unique_index", indexes);

    result_da = values.unique;
    check("locator result to dynamic array",
          result_da.size() == 3);
    result = result_da;
    check_values("dynamic result values", result);
    result_fixed = values.unique;
    result = result_fixed;
    check_values("locator result to fixed array", result);

    empty = new[0];
    result = empty.unique;
    indexes = empty.unique_index;
    check("empty results", result.size() == 0 && indexes.size() == 0);

    result = never_allocated.unique;
    indexes = never_allocated.unique_index;
    check("never-allocated dynamic array returns fresh empty queues",
          result.size() == 0 && indexes.size() == 0);
    fresh_results.push_back(never_allocated.unique);
    fresh_results.push_back(never_allocated.unique_index);
    check("never-allocated locator results are stored queue values",
          fresh_results.size() == 2
          && fresh_results[0].size() == 0
          && fresh_results[1].size() == 0);
    fresh_results[0][0] = 71;
    fresh_results[1].push_back(72);
    check("stored empty locator results remain usable",
          fresh_results[0].size() == 1 && fresh_results[0][0] == 71
          && fresh_results[1].size() == 1 && fresh_results[1][0] == 72);

    queue_values = '{10, 3, 10, 20, 3};
    result = queue_values.unique;
    check_values("queue unique without parentheses", result);
    indexes = queue_values.unique_index;
    check_queue_indexes("queue unique_index", indexes);
    check("queue source unchanged",
          queue_values.size() == 5 && queue_values[0] == 10
          && queue_values[4] == 3);

    bounded_values = '{10, 10, 3};
    result = bounded_values.unique;
    result.sort();
    check("bounded receiver returns unbounded result",
          result.size() == 2 && result[0] == 3 && result[1] == 10);

    wide_values = '{40'h123456789a, 40'h123456789a, 40'hfedcba9876};
    wide_result = wide_values.unique;
    wide_result.sort();
    check("wide element type retained",
          wide_result.size() == 2
          && wide_result[0] == 40'h123456789a
          && wide_result[1] == 40'hfedcba9876);

    fixed_values = '{10, 10, 3, 20, 20, 10};
    result = fixed_values.unique;
    check_values("fixed unique without parentheses", result);
    indexes = fixed_values.unique_index;
    check_fixed_indexes("fixed unique_index", indexes);
    check("fixed source unchanged",
          fixed_values[0] == 10 && fixed_values[5] == 10);

    fixed_descending = '{10, 10, 3, 20, 20, 10};
    result = fixed_descending.unique;
    check_values("descending fixed unique", result);
    indexes = fixed_descending.unique_index;
    check_descending_indexes("descending fixed unique_index uses declared indexes",
                             indexes);

    fixed_nonzero = '{10, 10, 3};
    result = fixed_nonzero.unique;
    result.sort();
    check("nonzero-base fixed value result",
          result.size() == 2 && result[0] == 3 && result[1] == 10);
    indexes = fixed_nonzero.unique_index;
    check_nonzero_indexes("nonzero-base fixed unique_index uses declared indexes",
                          indexes);

    member_values = new[1];
    member_values[0].unique_index = 42;
    scalar_result = member_values[0].unique_index;
    check("element member named unique_index is not a locator",
          scalar_result == 42);

    statement_queue = '{3, 1, 2, 1, 3};
    statement_queue.unique();
    statement_queue.unique_index();
    check("discarded queue locator leaves receiver unchanged",
          statement_queue.size() == 5
          && statement_queue[0] == 3 && statement_queue[1] == 1
          && statement_queue[2] == 2 && statement_queue[3] == 1
          && statement_queue[4] == 3);

    values.unique();
    values.unique_index();
    check("discarded dynamic locator leaves receiver unchanged",
          values.size() == 6 && values[0] == 10 && values[5] == 10);

    fixed_values.unique();
    check("discarded fixed locator leaves receiver unchanged",
          fixed_values[0] == 10 && fixed_values[5] == 10);

    if (failed)
      $fatal(1, "unique checks failed");
    $display("PASSED");
  end
endmodule
