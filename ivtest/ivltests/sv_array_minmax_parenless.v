// IEEE 1800-2017 7.12/7.12.1: min/max are queue-valued array locator
// methods, and the iterator-argument parentheses may be omitted.
module main;
  typedef struct {
    int min;
    int max;
  } extrema_t;

  int values[];
  int empty[];
  int result[$];
  int result_da[];
  int result_fixed[1];
  int queue_values[$];
  int bounded_values[$:2];
  bit [7:0] unsigned_values[];
  bit [7:0] unsigned_result[$];
  int fixed_ascending[0:4];
  int fixed_descending[4:0];
  int fixed_nonzero[5:9];
  extrema_t member_values[];
  int scalar_result;
  bit failed;

  task automatic check(input string label, input logic ok);
    if (ok !== 1'b1) begin
      $display("FAILED -- %0s", label);
      failed = 1'b1;
    end
  endtask

  initial begin
    failed = 1'b0;
    values = '{10, -4, 30, -4, 5};

    result = values.min;
    check("dynamic min without parentheses",
          result.size() == 1 && result[0] == -4);
    result = values.max;
    check("dynamic max without parentheses",
          result.size() == 1 && result[0] == 30);
    check("dynamic source unchanged",
          values.size() == 5 && values[0] == 10 && values[4] == 5);

    member_values = new[1];
    member_values[0].min = 41;
    member_values[0].max = 42;
    scalar_result = member_values[0].min;
    check("element member named min is not a locator", scalar_result == 41);
    scalar_result = member_values[0].max;
    check("element member named max is not a locator", scalar_result == 42);

    result = values.min();
    check("dynamic min call control",
          result.size() == 1 && result[0] == -4);
    result = values.max();
    check("dynamic max call control",
          result.size() == 1 && result[0] == 30);

    result_da = values.min;
    check("locator result to dynamic array",
          result_da.size() == 1 && result_da[0] == -4);
    result_fixed = values.max;
    check("locator result to fixed array", result_fixed[0] == 30);

    empty = new[0];
    result = empty.min;
    check("empty min", result.size() == 0);
    result = empty.max;
    check("empty max", result.size() == 0);

    queue_values = '{9, -7, 12, 4};
    result = queue_values.min;
    check("queue min without parentheses",
          result.size() == 1 && result[0] == -7);
    result = queue_values.max;
    check("queue max without parentheses",
          result.size() == 1 && result[0] == 12);
    check("queue source unchanged",
          queue_values.size() == 4 && queue_values[0] == 9
          && queue_values[3] == 4);

    bounded_values = '{6, 2, 11};
    result = bounded_values.max;
    check("bounded receiver returns unbounded result",
          result.size() == 1 && result[0] == 11);

    unsigned_values = '{8'hf0, 8'h0f, 8'h80};
    unsigned_result = unsigned_values.min;
    check("unsigned min",
          unsigned_result.size() == 1 && unsigned_result[0] == 8'h0f);
    unsigned_result = unsigned_values.max;
    check("unsigned max",
          unsigned_result.size() == 1 && unsigned_result[0] == 8'hf0);

    // Fixed arrays retain their established no-parentheses lowering. These
    // controls ensure this dynamic/queue fix does not redirect that path.
    fixed_ascending = '{10, -4, 30, 5, 8};
    fixed_descending = '{10, -4, 30, 5, 8};
    fixed_nonzero = '{10, -4, 30, 5, 8};
    result = fixed_ascending.max;
    check("fixed ascending control", result.size() == 1 && result[0] == 30);
    result = fixed_descending.min;
    check("fixed descending control", result.size() == 1 && result[0] == -4);
    result = fixed_nonzero.max;
    check("fixed nonzero-base control", result.size() == 1 && result[0] == 30);

    if (failed)
      $fatal(1, "min/max checks failed");
    $display("PASSED");
  end
endmodule
