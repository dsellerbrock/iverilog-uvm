// IEEE 1800-2017 7.12.1 associative unique()/unique_index(): exact index
// result types, order-independent representatives, class-property receivers,
// and fresh empty results.
class assoc_unique_holder;
  int values[string];
endclass

module main;
  typedef enum logic [3:0] { KEY_A = 4'h1, KEY_B = 4'h4,
                             KEY_C = 4'h9 } key_t;

  bit failed;
  int by_int[int];
  int int_values[$];
  int int_indexes[$];
  int parity_indexes[$];

  int by_string[string];
  string string_indexes[$];

  int by_enum[key_t];
  key_t enum_indexes[$];
  key_t every_enum_index[$];

  int empty_values[string];
  int empty_result_a[$];
  int empty_result_b[$];
  string empty_index_a[$];
  string empty_index_b[$];

  assoc_unique_holder holder;
  string property_indexes[$];
  string arbitrary_indexes[$];
  int receiver_calls;

  function assoc_unique_holder get_holder;
    receiver_calls = receiver_calls + 1;
    return holder;
  endfunction

  function int enum_index_code(input key_t key);
    return int'(key);
  endfunction

  task automatic check(input string label, input logic ok);
    if (ok !== 1'b1) begin
      $display("FAILED -- %0s", label);
      failed = 1'b1;
    end
  endtask

  initial begin
    int i;
    bit seen_10;
    bit seen_20;
    bit seen_31;
    bit seen_even;
    bit seen_odd;
    bit seen_one;
    bit seen_two;

    failed = 1'b0;

    by_int[-5] = 10;
    by_int[4] = 10;
    by_int[100] = 20;
    by_int[7] = 31;
    int_values = by_int.unique;
    int_indexes = by_int.unique_index();
    check("integral unique size", int_values.size() == 3);
    check("integral unique_index size", int_indexes.size() == 3);
    seen_10 = 0; seen_20 = 0; seen_31 = 0;
    for (i = 0; i < int_values.size(); i = i + 1) begin
      if (int_values[i] == 10) begin
        check("one integral value 10", !seen_10); seen_10 = 1;
      end else if (int_values[i] == 20) begin
        check("one integral value 20", !seen_20); seen_20 = 1;
      end else if (int_values[i] == 31) begin
        check("one integral value 31", !seen_31); seen_31 = 1;
      end else begin
        check("integral unique member", 0);
      end
    end
    check("all integral values", seen_10 && seen_20 && seen_31);
    seen_10 = 0; seen_20 = 0; seen_31 = 0;
    for (i = 0; i < int_indexes.size(); i = i + 1) begin
      check("integral returned index exists", by_int.exists(int_indexes[i]));
      if (by_int.exists(int_indexes[i])) begin
        if (by_int[int_indexes[i]] == 10) begin
          check("one integral index for 10", !seen_10); seen_10 = 1;
        end else if (by_int[int_indexes[i]] == 20) begin
          check("one integral index for 20", !seen_20); seen_20 = 1;
        end else if (by_int[int_indexes[i]] == 31) begin
          check("one integral index for 31", !seen_31); seen_31 = 1;
        end else begin
          check("integral index representative", 0);
        end
      end
    end
    check("all integral indexes", seen_10 && seen_20 && seen_31);

    parity_indexes = by_int.unique_index(value) with (value & 1);
    check("integral with size", parity_indexes.size() == 2);
    seen_even = 0; seen_odd = 0;
    for (i = 0; i < parity_indexes.size(); i = i + 1) begin
      check("parity returned index exists", by_int.exists(parity_indexes[i]));
      if (by_int.exists(parity_indexes[i])) begin
        if (by_int[parity_indexes[i]] & 1) begin
          check("one odd representative", !seen_odd); seen_odd = 1;
        end else begin
          check("one even representative", !seen_even); seen_even = 1;
        end
      end
    end
    check("both parity representatives", seen_even && seen_odd);

    by_string["alpha"] = 1;
    by_string["beta"] = 1;
    by_string["gamma"] = 2;
    string_indexes = by_string.unique_index;
    check("string exact result type and size", string_indexes.size() == 2);
    seen_one = 0; seen_two = 0;
    for (i = 0; i < string_indexes.size(); i = i + 1) begin
      check("string returned index exists", by_string.exists(string_indexes[i]));
      if (by_string.exists(string_indexes[i])) begin
        if (by_string[string_indexes[i]] == 1) begin
          check("one string index for one", !seen_one); seen_one = 1;
        end else if (by_string[string_indexes[i]] == 2) begin
          check("one string index for two", !seen_two); seen_two = 1;
        end else begin
          check("string index representative", 0);
        end
      end
    end
    check("all string index groups", seen_one && seen_two);

    by_enum[KEY_A] = 6;
    by_enum[KEY_B] = 6;
    by_enum[KEY_C] = 9;
    enum_indexes = by_enum.unique_index();
    check("enum exact result type and size", enum_indexes.size() == 2);
    seen_one = 0; seen_two = 0;
    for (i = 0; i < enum_indexes.size(); i = i + 1) begin
      check("enum returned index exists", by_enum.exists(enum_indexes[i]));
      if (by_enum.exists(enum_indexes[i])) begin
        if (by_enum[enum_indexes[i]] == 6) begin
          check("one enum index for six", !seen_one); seen_one = 1;
        end else if (by_enum[enum_indexes[i]] == 9) begin
          check("one enum index for nine", !seen_two); seen_two = 1;
        end else begin
          check("enum index representative", 0);
        end
      end
    end
    check("all enum index groups", seen_one && seen_two);
    every_enum_index = by_enum.unique_index(v)
                       with (enum_index_code(v.index()));
    check("enum iterator index() retains its declared type",
          every_enum_index.size() == 3);

    holder = new;
    holder.values["left"] = 2;
    holder.values["middle"] = 2;
    holder.values["right"] = 3;
    property_indexes = holder.values.unique_index(v) with (v);
    check("class-property receiver", property_indexes.size() == 2);
    for (i = 0; i < property_indexes.size(); i = i + 1)
      check("class-property returned index exists",
            holder.values.exists(property_indexes[i]));

    receiver_calls = 0;
    arbitrary_indexes = get_holder().values.unique_index(v) with (v);
    check("arbitrary receiver evaluated once",
          receiver_calls == 1 && arbitrary_indexes.size() == 2);

    empty_result_a = empty_values.unique;
    empty_result_a.push_back(99);
    empty_result_b = empty_values.unique;
    empty_index_a = empty_values.unique_index;
    empty_index_a.push_back("sentinel");
    empty_index_b = empty_values.unique_index;
    check("empty value result is fresh", empty_result_a.size() == 1
          && empty_result_b.size() == 0);
    check("empty exact-index result is fresh", empty_index_a.size() == 1
          && empty_index_b.size() == 0);
    check("sources are unchanged", by_int.num() == 4
          && by_string.num() == 3 && by_enum.num() == 3
          && holder.values.num() == 3);

    if (failed)
      $display("FAILED");
    else
      $display("PASSED");
  end
endmodule
