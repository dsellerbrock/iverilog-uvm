// IEEE 1800-2017 7.12.1: unique()/unique_index() may use one with-clause
// expression as an equality key. Exercise scalar queue/dynamic-array
// receivers and integral (full-width four-state), real, and string keys.
// Result order and the representative chosen for a duplicate key are not
// specified, so every check below is set-based.
class scalar_unique_holder;
  int values[];
  logic [7:0] queued[$];
endclass

module main;
  typedef int int_queue_t[$];

  int receiver_calls;
  bit failed;

  int int_values[];
  int int_result[$];
  int indexes[$];
  int empty_values[];
  int empty_results[$][$];

  logic [71:0] wide_values[$];
  logic [71:0] wide_result[$];
  logic [7:0] byte_result[$];

  real real_values[];
  real real_result[$];

  string string_values[$];
  string string_result[$];

  scalar_unique_holder holder;

  task automatic check(input string label, input logic ok);
    if (ok !== 1'b1) begin
      $display("FAILED -- %0s", label);
      failed = 1'b1;
    end
  endtask

  function automatic int_queue_t make_queue();
    int_queue_t value;
    receiver_calls = receiver_calls + 1;
    value = '{30, 32, 31, 33};
    return value;
  endfunction

  task automatic check_parity_values(input string label, input int got[$]);
    bit even_seen;
    bit odd_seen;
    int i;
    even_seen = 1'b0;
    odd_seen = 1'b0;
    check(label, got.size() == 2);
    for (i = 0; i < got.size(); i = i + 1) begin
      check("parity value belongs to receiver",
            got[i] == 10 || got[i] == 12 || got[i] == 11
            || got[i] == 13 || got[i] == 14);
      if ((got[i] & 1) == 0) begin
        check("one even representative", !even_seen);
        even_seen = 1'b1;
      end else begin
        check("one odd representative", !odd_seen);
        odd_seen = 1'b1;
      end
    end
    check(label, even_seen && odd_seen);
  endtask

  task automatic check_parity_indexes(input string label, input int got[$]);
    bit even_seen;
    bit odd_seen;
    int i;
    even_seen = 1'b0;
    odd_seen = 1'b0;
    check(label, got.size() == 2);
    for (i = 0; i < got.size(); i = i + 1) begin
      check("parity index range",
            got[i] >= 0 && got[i] < int_values.size());
      if (got[i] >= 0 && got[i] < int_values.size()) begin
        if ((int_values[got[i]] & 1) == 0) begin
          check("one even index", !even_seen);
          even_seen = 1'b1;
        end else begin
          check("one odd index", !odd_seen);
          odd_seen = 1'b1;
        end
      end
    end
    check(label, even_seen && odd_seen);
  endtask

  task automatic check_wide_values(input string label,
                                    input logic [71:0] got[$]);
    bit seen_a;
    bit seen_b;
    bit seen_x;
    bit seen_z;
    int i;
    seen_a = 1'b0;
    seen_b = 1'b0;
    seen_x = 1'b0;
    seen_z = 1'b0;
    check(label, got.size() == 4);
    for (i = 0; i < got.size(); i = i + 1) begin
      if (got[i] === 72'h010000000000000001) begin
        check("one wide A", !seen_a); seen_a = 1'b1;
      end else if (got[i] === 72'h020000000000000001) begin
        check("one wide B", !seen_b); seen_b = 1'b1;
      end else if (got[i] === 72'h03000000000000000x) begin
        check("one wide X", !seen_x); seen_x = 1'b1;
      end else if (got[i] === 72'h03000000000000000z) begin
        check("one wide Z", !seen_z); seen_z = 1'b1;
      end else begin
        check("wide representative value", 1'b0);
      end
    end
    check(label, seen_a && seen_b && seen_x && seen_z);
  endtask

  task automatic check_wide_indexes(input string label, input int got[$]);
    logic [71:0] represented[$];
    int i;
    for (i = 0; i < got.size(); i = i + 1) begin
      check("wide index range",
            got[i] >= 0 && got[i] < wide_values.size());
      if (got[i] >= 0 && got[i] < wide_values.size())
        represented.push_back(wide_values[got[i]]);
    end
    check_wide_values(label, represented);
  endtask

  task automatic check_real_values(input string label, input real got[$]);
    bit seen_neg;
    bit seen_one;
    bit seen_two;
    int i;
    seen_neg = 1'b0;
    seen_one = 1'b0;
    seen_two = 1'b0;
    check(label, got.size() == 3);
    for (i = 0; i < got.size(); i = i + 1) begin
      if (got[i] == -3.5) begin
        check("one real -3.5", !seen_neg); seen_neg = 1'b1;
      end else if (got[i] == 1.25) begin
        check("one real 1.25", !seen_one); seen_one = 1'b1;
      end else if (got[i] == 2.5) begin
        check("one real 2.5", !seen_two); seen_two = 1'b1;
      end else begin
        check("real representative value", 1'b0);
      end
    end
    check(label, seen_neg && seen_one && seen_two);
  endtask

  task automatic check_real_indexes(input string label, input int got[$]);
    real represented[$];
    int i;
    for (i = 0; i < got.size(); i = i + 1) begin
      check("real keyed index range",
            got[i] >= 0 && got[i] < real_values.size());
      if (got[i] >= 0 && got[i] < real_values.size())
        represented.push_back(real_values[got[i]]);
    end
    check_real_values(label, represented);
  endtask

  task automatic check_string_values(input string label,
                                      input string got[$]);
    bit seen_red;
    bit seen_blue;
    bit seen_green;
    int i;
    seen_red = 1'b0;
    seen_blue = 1'b0;
    seen_green = 1'b0;
    check(label, got.size() == 3);
    for (i = 0; i < got.size(); i = i + 1) begin
      if (got[i] == "red") begin
        check("one red", !seen_red); seen_red = 1'b1;
      end else if (got[i] == "blue") begin
        check("one blue", !seen_blue); seen_blue = 1'b1;
      end else if (got[i] == "green") begin
        check("one green", !seen_green); seen_green = 1'b1;
      end else begin
        check("string representative value", 1'b0);
      end
    end
    check(label, seen_red && seen_blue && seen_green);
  endtask

  task automatic check_string_indexes(input string label, input int got[$]);
    string represented[$];
    int i;
    for (i = 0; i < got.size(); i = i + 1) begin
      check("string keyed index range",
            got[i] >= 0 && got[i] < string_values.size());
      if (got[i] >= 0 && got[i] < string_values.size())
        represented.push_back(string_values[got[i]]);
    end
    check_string_values(label, represented);
  endtask

  initial begin
    failed = 1'b0;
    int_values = '{10, 12, 11, 13, 14};

    int_result = int_values.unique(value) with (value & 1);
    check_parity_values("dynamic-array unique with integral key", int_result);

    indexes = int_values.unique_index(value) with (value & 1);
    check_parity_indexes("dynamic-array unique_index with integral key",
                         indexes);
    check("integral source unchanged",
          int_values.size() == 5 && int_values[0] == 10
          && int_values[1] == 12 && int_values[2] == 11
          && int_values[3] == 13 && int_values[4] == 14);

    wide_values = '{72'h010000000000000001,
                    72'h020000000000000001,
                    72'h010000000000000001,
                    72'h03000000000000000x,
                    72'h03000000000000000x,
                    72'h03000000000000000z};
    wide_result = wide_values.unique(wide) with (wide);
    check_wide_values("full-width four-state unique key", wide_result);
    indexes = wide_values.unique_index(wide) with (wide);
    check_wide_indexes("full-width four-state unique_index key", indexes);

    real_values = '{1.25, 2.5, 1.25, -3.5, 2.5};
    real_result = real_values.unique(r) with (r);
    check_real_values("real element and key", real_result);
    indexes = real_values.unique_index(r) with (r);
    check_real_indexes("real keyed indexes", indexes);

    string_values = '{"red", "blue", "red", "green", "blue"};
    string_result = string_values.unique(text) with (text);
    check_string_values("string element and key", string_result);
    indexes = string_values.unique_index(text) with (text);
    check_string_indexes("string keyed indexes", indexes);

    holder = new;
    holder.values = '{20, 21, 22, 23};
    holder.queued = '{8'h11, 8'h21, 8'h12, 8'h22};
    int_result = holder.values.unique with (item & 1);
    check("class-property default iterator unique", int_result.size() == 2);
    indexes = holder.values.unique_index(entry) with (entry & 1);
    check("class-property named iterator unique_index", indexes.size() == 2);
    byte_result = holder.queued.unique(byte_value) with (byte_value[3:0]);
    check("class-property queue keyed unique", byte_result.size() == 2);

    receiver_calls = 0;
    int_result = make_queue().unique(entry) with (entry & 1);
    check("arbitrary receiver evaluated once", receiver_calls == 1);
    check("arbitrary receiver result", int_result.size() == 2);

    receiver_calls = 0;
    make_queue().unique();
    check("discarded call-result receiver evaluated once", receiver_calls == 1);

    empty_results.push_back(
        empty_values.unique(entry) with (entry & 1));
    empty_results.push_back(
        empty_values.unique_index(entry) with (entry & 1));
    check("null calls return empty containers",
          empty_results.size() == 2
          && empty_results[0].size() == 0
          && empty_results[1].size() == 0);
    empty_results[0].push_back(99);
    check("null results are fresh usable queues",
          empty_results[0].size() == 1
          && empty_results[1].size() == 0
          && empty_values.size() == 0);

    int_values.unique with (item & 1);
    check("discarded keyed result leaves source unchanged",
          int_values.size() == 5 && int_values[0] == 10
          && int_values[4] == 14);

    if (failed)
      $fatal(1, "scalar unique-with checks failed");
    $display("PASSED");
  end
endmodule
