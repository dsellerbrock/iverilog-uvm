// IEEE 1800-2017 Syntax 7-5: an array manipulation call may place
// attribute_instance nodes after the method name and before the optional
// iterator parentheses. Attributes do not change unique/unique_index
// semantics. Result order and the duplicate representative index are
// unspecified, so all result checks are set-based.
class unique_attribute_holder;
  int values[];
  int unique_index;
endclass

class scoped_static_method_holder #(int TAG = 0);
  static int values[$];
endclass

module main;
  typedef int int_queue_t[$];
  typedef struct {
    int unique_index;
  } field_holder_t;

  unique_attribute_holder holder;
  field_holder_t fields;
  int result[$];
  int indexes[$];
  int receiver_calls;
  bit failed;

  task automatic check(input string label, input logic ok);
    if (ok !== 1'b1) begin
      $display("FAILED -- %0s", label);
      failed = 1'b1;
    end
  endtask

  function automatic int_queue_t make_queue();
    int_queue_t value;
    receiver_calls = receiver_calls + 1;
    value = '{10, 10, 3, 20, 20};
    return value;
  endfunction

  task automatic check_values(input string label, input int got[$]);
    got.sort();
    check(label, got.size() == 3
          && got[0] == 3 && got[1] == 10 && got[2] == 20);
  endtask

  task automatic check_indexes(input string label, input int got[$]);
    bit seen_3;
    bit seen_10;
    bit seen_20;
    int i;
    seen_3 = 1'b0;
    seen_10 = 1'b0;
    seen_20 = 1'b0;
    check(label, got.size() == 3);
    for (i = 0; i < got.size(); i = i + 1) begin
      check("unique_index range", got[i] >= 0 && got[i] < 5);
      case (got[i])
        0, 1: begin check("one value 10 index", !seen_10); seen_10 = 1'b1; end
        2: begin check("one value 3 index", !seen_3); seen_3 = 1'b1; end
        3, 4: begin check("one value 20 index", !seen_20); seen_20 = 1'b1; end
        default: check("valid unique_index", 1'b0);
      endcase
    end
    check(label, seen_3 && seen_10 && seen_20);
  endtask

  task automatic check_parity_indexes(input string label, input int got[$]);
    bit seen_even;
    bit seen_odd;
    int i;
    seen_even = 1'b0;
    seen_odd = 1'b0;
    check(label, got.size() == 2);
    for (i = 0; i < got.size(); i = i + 1) begin
      check("parity index range", got[i] >= 0 && got[i] < 5);
      if (got[i] == 2) begin
        check("one odd index", !seen_odd);
        seen_odd = 1'b1;
      end else if (got[i] >= 0 && got[i] < 5) begin
        check("one even index", !seen_even);
        seen_even = 1'b1;
      end
    end
    check(label, seen_even && seen_odd);
  endtask

  initial begin
    failed = 1'b0;
    receiver_calls = 0;
    holder = new;
    holder.values = '{10, 10, 3, 20, 20};
    holder.unique_index = 41;
    fields.unique_index = 42;

    // A parameterized class static receiver must retain its specialization
    // through keyword-named and attributed array method calls.
    scoped_static_method_holder#()::values = '{10, 10, 3, 20, 20};
    result = scoped_static_method_holder#()::values.unique();
    check_values("scoped static unique", result);
    check("scoped static and",
          scoped_static_method_holder#()::values.and() == 0);
    indexes = scoped_static_method_holder#()::values.find_index
        (* keep = 1 *) (entry) with (entry == 20);
    check("scoped static attributed find_index",
          indexes.size() == 2 && indexes[0] == 3 && indexes[1] == 4);

    // Hierarchical receivers: explicit empty parentheses and omitted
    // iterator parentheses for both keyword- and identifier-named methods.
    result = holder.values.unique (* hierarchy_unique = 1 *) ();
    check_values("hierarchy unique attribute with empty parentheses", result);
    indexes = holder.values.unique_index (* hierarchy_index, second = 2 *);
    check_indexes("hierarchy unique_index attribute parenless", indexes);

    // Named and default iterators, both with trailing with-clauses.
    result = holder.values.unique (* named_iterator = "yes" *) (entry)
        with (entry & 1);
    check("hierarchy named iterator with", result.size() == 2);
    indexes = holder.values.unique_index (* default_iterator *)
        with (item & 1);
    check_parity_indexes("hierarchy default iterator with", indexes);

    // Arbitrary primary / call-result receivers. Multiple attribute
    // instances are legal and the receiver must still be evaluated once.
    receiver_calls = 0;
    result = make_queue().unique (* call_result_a = 1 *)
        (* call_result_b = 2 *) (entry) with (entry & 1);
    check("call-result expression evaluated once", receiver_calls == 1);
    check("call-result named iterator with", result.size() == 2);

    receiver_calls = 0;
    indexes = make_queue().unique_index (* call_result_index *) ();
    check("call-result unique_index evaluated once", receiver_calls == 1);
    check_indexes("call-result unique_index attribute", indexes);

    receiver_calls = 0;
    result = make_queue().unique (* call_result_parenless *);
    check("call-result parenless evaluated once", receiver_calls == 1);
    check_values("call-result parenless attribute", result);

    // Discarded-result statement forms cover hierarchy/call-result,
    // unique/unique_index, parentheses/no parentheses, and trailing with.
    holder.values.unique (* statement_hierarchy *) ();
    holder.values.unique_index (* statement_index *)
        with (item & 1);
    holder.values.unique_index (* statement_index_explicit *) ();
    holder.values.unique_index (* statement_index_named *) (entry)
        with (entry & 1);

    receiver_calls = 0;
    make_queue().unique (* statement_call_result *) (entry)
        with (entry & 1);
    check("discarded call-result unique evaluated once", receiver_calls == 1);

    receiver_calls = 0;
    make_queue().unique_index (* statement_index_parenless *);
    check("discarded call-result unique_index evaluated once",
          receiver_calls == 1);

    check("attributes do not consume struct/class fields named unique_index",
          holder.unique_index == 41 && fields.unique_index == 42);
    check("source remains unchanged",
          holder.values.size() == 5
          && holder.values[0] == 10 && holder.values[1] == 10
          && holder.values[2] == 3 && holder.values[3] == 20
          && holder.values[4] == 20);

    if (failed)
      $fatal(1, "array unique attribute checks failed");
    $display("PASSED");
  end
endmodule
