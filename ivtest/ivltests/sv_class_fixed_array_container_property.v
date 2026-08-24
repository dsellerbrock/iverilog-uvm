// A non-static class property may be a fixed unpacked array whose elements
// are queues or associative arrays (IEEE 1800-2017 7.4, 7.8-7.10 and 8.5).
// Keep the fixed-array slot distinct from every trailing container index.

typedef struct packed {
  int delay;
  bit state;
} pred_t;

typedef int bounded_int_q_t[$:1];

typedef struct {
  int values[$];
} plain_queue_struct_t;

typedef struct {
  int count;
} fixed_assoc_value_t;

class fixed_array_container_leaf;
  int hits;

  function void sample();
    hits++;
  endfunction
endclass

class fixed_array_container_item;
  int value;

  function new(int value = 0);
    this.value = value;
  endfunction

  function void bump();
    value++;
  endfunction
endclass

class fixed_array_container_holder;
  typedef byte unsigned byte_q_t[$];

  pred_t pred[2:1][$];
  byte_q_t mem[-1:1];
  fixed_array_container_item items[0:1][$];
  fixed_array_container_leaf cov[0:1][string];
  int multi[1:0][3:4][$];
  int bounded_values[-1:0][$:1];
  fixed_array_container_item bounded_items[0:1][$:1];
  real real_values[0:1][$];
  string string_values[0:1][$];
  bounded_int_q_t nested_values[0:1][$];
  fixed_assoc_value_t struct_values[0:1][$];
  fixed_assoc_value_t bounded_struct_values[0:1][$:1];
  fixed_assoc_value_t records[0:1][string];
endclass

module sv_class_fixed_array_container_property;
  bit failed;
  fixed_array_container_holder function_holder;
  plain_queue_struct_t struct_words[2];
  bounded_int_q_t signal_nested_values[$];
  int holder_receiver_calls;
  int receiver_index_calls;

  function automatic fixed_array_container_holder get_holder();
    holder_receiver_calls++;
    return function_holder;
  endfunction

  function automatic int next_item_outer();
    receiver_index_calls++;
    return 1;
  endfunction

  function automatic int next_mem_outer();
    receiver_index_calls++;
    return -1;
  endfunction

  task automatic check(input string label, input bit ok);
    if (!ok) begin
      $display("FAILED -- %0s", label);
      failed = 1'b1;
    end
  endtask

  initial begin
    automatic fixed_array_container_holder holder = new;
    automatic fixed_array_container_item item = new(19);
    automatic fixed_array_container_item bounded_item_a = new(101);
    automatic fixed_array_container_item bounded_item_b = new(202);
    automatic fixed_array_container_item bounded_item_c = new(303);
    automatic fixed_array_container_item bounded_item_d = new(404);
    automatic pred_t prediction;
    automatic byte unsigned source[$] = '{8'h11, 8'h22};
    automatic byte unsigned sliced[$];
    automatic byte unsigned insert_bytes[$] = '{8'h44, 8'h55};
    automatic real insert_reals[$] = '{3.5, 4.5};
    automatic string insert_strings[$] = '{"left", "right"};
    automatic int nested_source[$] = '{4, 5, 6};
    automatic int insert_source_a[$] = '{101};
    automatic int insert_source_b[$] = '{201, 202, 203};
    automatic int insert_sources[$][$];
    automatic fixed_assoc_value_t struct_source;
    automatic fixed_assoc_value_t struct_copy;
    automatic fixed_assoc_value_t bounded_struct_a;
    automatic fixed_assoc_value_t bounded_struct_b;
    automatic fixed_assoc_value_t bounded_struct_c;
    automatic fixed_assoc_value_t bounded_struct_d;
    automatic fixed_array_container_holder returned_holder;

    function_holder = holder;

    prediction.delay = 3;
    prediction.state = 1'b1;
    holder.pred[1].push_back(prediction);
    holder.pred[1][0].delay--;
    check("packed-struct queue element",
          holder.pred[1].size() == 1 &&
          holder.pred[1][0].delay == 2 && holder.pred[1][0].state);
    check("descending outer slot independence", holder.pred[2].size() == 0);

    holder.mem[-1] = source;
    source.push_back(8'h33);
    check("whole-inner value copy",
          holder.mem[-1].size() == 2 && holder.mem[-1][0] == 8'h11 &&
          holder.mem[-1][1] == 8'h22 && source.size() == 3);
    sliced = holder.mem[-1][0:1];
    holder.mem[1] = holder.mem[-1][1:$];
    check("trailing queue slices",
          sliced.size() == 2 && sliced[0] == 8'h11 && sliced[1] == 8'h22 &&
          holder.mem[1].size() == 1 && holder.mem[1][0] == 8'h22);
    check("ascending outer slot independence", holder.mem[0].size() == 0);
    holder.mem[0].push_back(8'h10);
    holder.mem[0].insert(0, insert_bytes[1]);
    check("vec4 insert preserves position across RHS index",
          holder.mem[0].size() == 2 && holder.mem[0][0] == 8'h55 &&
          holder.mem[0][1] == 8'h10);

    // A selected fixed property slot is the direct bounded queue receiver.
    // [$:1] permits exactly two elements; every mutator must retain that bound.
    holder.bounded_values[-1].push_back(10);
    holder.bounded_values[-1].push_back(20);
    holder.bounded_values[-1].push_back(30);
    holder.bounded_values[-1].insert(1, 15);
    holder.bounded_values[-1].push_front(5);
    check("direct selected bounded vector queue honors declared maximum",
          holder.bounded_values[-1].size() == 2 &&
          holder.bounded_values[-1][0] == 5 &&
          holder.bounded_values[-1][1] == 10 &&
          holder.bounded_values[0].size() == 0);

    // Class handles and unpacked structs both use object-backed queue storage,
    // but class elements retain handle identity while structs copy by value.
    receiver_index_calls = 0;
    holder.bounded_items[next_item_outer()].push_back(bounded_item_a);
    check("selected class queue push receiver evaluated once",
          receiver_index_calls == 1);
    receiver_index_calls = 0;
    holder.bounded_items[next_item_outer()].push_front(bounded_item_b);
    check("selected class queue push-front receiver evaluated once",
          receiver_index_calls == 1);
    receiver_index_calls = 0;
    holder.bounded_items[next_item_outer()].push_back(bounded_item_c);
    check("full selected class queue push receiver evaluated once",
          receiver_index_calls == 1);
    receiver_index_calls = 0;
    holder.bounded_items[next_item_outer()].insert(1, bounded_item_d);
    check("selected class queue insert receiver evaluated once",
          receiver_index_calls == 1);
    holder.bounded_items[1][1].bump();
    check("bounded class queue uses object dispatch and handle semantics",
          holder.bounded_items[1].size() == 2 &&
          holder.bounded_items[1][0].value == 202 &&
          holder.bounded_items[1][1].value == 405 &&
          bounded_item_d.value == 405 &&
          holder.bounded_items[0].size() == 0);

    bounded_struct_a.count = 11;
    bounded_struct_b.count = 22;
    bounded_struct_c.count = 33;
    bounded_struct_d.count = 44;
    receiver_index_calls = 0;
    holder.bounded_struct_values[next_item_outer()].push_back(
        bounded_struct_a);
    check("selected struct queue push receiver evaluated once",
          receiver_index_calls == 1);
    receiver_index_calls = 0;
    holder.bounded_struct_values[next_item_outer()].push_front(
        bounded_struct_b);
    check("selected struct queue push-front receiver evaluated once",
          receiver_index_calls == 1);
    receiver_index_calls = 0;
    holder.bounded_struct_values[next_item_outer()].push_back(
        bounded_struct_c);
    check("full selected struct queue push receiver evaluated once",
          receiver_index_calls == 1);
    receiver_index_calls = 0;
    holder.bounded_struct_values[next_item_outer()].insert(
        1, bounded_struct_d);
    check("selected struct queue insert receiver evaluated once",
          receiver_index_calls == 1);
    bounded_struct_d.count = 99;
    check("bounded unpacked-struct queue uses object value dispatch",
          holder.bounded_struct_values[1].size() == 2 &&
          holder.bounded_struct_values[1][0].count == 22 &&
          holder.bounded_struct_values[1][1].count == 44 &&
          holder.bounded_struct_values[0].size() == 0);

    holder_receiver_calls = 0;
    returned_holder = get_holder();
    check("function-return fixed-container handle",
          returned_holder.mem[-1].size() == 2 && holder_receiver_calls == 1);

    holder.real_values[0].push_back(1.25);
    holder.real_values[0][0] = 2.5;
    holder.string_values[1].push_back("before");
    holder.string_values[1][0] = "after";
    holder.real_values[1].push_back(1.0);
    holder.real_values[1].insert(0, insert_reals[1]);
    holder.string_values[0].push_back("before");
    holder.string_values[0].insert(0, insert_strings[1]);
    check("real and string queue element stores",
          holder.real_values[0][0] == 2.5 &&
          holder.real_values[0][$] == 2.5 &&
          holder.string_values[1][0] == "after" &&
          holder.string_values[1][$] == "after" &&
          holder.real_values[1].size() == 2 &&
          holder.real_values[1][0] == 4.5 &&
          holder.string_values[0].size() == 2 &&
          holder.string_values[0][0] == "right");

    holder.nested_values[0].push_back(nested_source);
    holder.nested_values[0][0] = nested_source;
    nested_source[0] = 99;
    check("queue-valued positional element copy and bound",
          holder.nested_values[0][0].size() == 2 &&
          holder.nested_values[0][0][0] == 4 &&
          holder.nested_values[0][0][1] == 5);

    insert_sources.push_back(insert_source_a);
    insert_sources.push_back(insert_source_b);
    holder.nested_values[0].insert(0, insert_sources[1]);
    signal_nested_values.push_back(insert_sources[0]);
    signal_nested_values.insert(0, insert_sources[1]);
    insert_sources[1][0] = 999;
    check("object insert preserves position, value copy, and bound",
          holder.nested_values[0].size() == 2 &&
          holder.nested_values[0][0].size() == 2 &&
          holder.nested_values[0][0][0] == 201 &&
          holder.nested_values[0][0][1] == 202 &&
          holder.nested_values[0][1][0] == 4);
    check("signal insert preserves position, value copy, and bound",
          signal_nested_values.size() == 2 &&
          signal_nested_values[0].size() == 2 &&
          signal_nested_values[0][0] == 201 &&
          signal_nested_values[0][1] == 202 &&
          signal_nested_values[1][0] == 101);

    struct_source.count = 7;
    holder.struct_values[0].push_back(struct_source);
    struct_copy = holder.struct_values[0][$];
    struct_copy.count = 99;
    check("last-element unpacked-struct read has value semantics",
          struct_copy.count == 99 &&
          holder.struct_values[0][0].count == 7);

    holder.items[1].push_back(item);
    check("class-handle queue",
          holder.items[1].size() == 1 && holder.items[1][0].value == 19 &&
          holder.items[0].size() == 0);
    receiver_index_calls = 0;
    holder.items[next_item_outer()][$].bump();
    check("last-element method receiver evaluated once",
          receiver_index_calls == 1 && holder.items[1][0].value == 20);

    receiver_index_calls = 0;
    check("last-element expression receiver evaluated once",
          holder.mem[next_mem_outer()][$] == 8'h22 &&
          receiver_index_calls == 1);

    holder.cov[1]["rise"] = new;
    holder.cov[1]["rise"].sample();
    check("string-key associative element method",
          holder.cov[1].num() == 1 && holder.cov[1].exists("rise") &&
          holder.cov[1]["rise"].hits == 1 && holder.cov[0].num() == 0);
    holder.cov[1].delete("rise");
    check("string-key associative delete", holder.cov[1].num() == 0);

    holder.records[1]["seen"].count = 9;
    check("associative value-struct element materialization",
          holder.records[1].num() == 1 &&
          holder.records[1]["seen"].count == 9 &&
          holder.records[0].num() == 0);
    holder.records[1].delete("seen");

    holder.multi[0][4].push_back(77);
    check("multidimensional fixed prefix",
          holder.multi[0][4].size() == 1 && holder.multi[0][4][0] == 77 &&
          holder.multi[1][3].size() == 0);

    struct_words[0].values.push_back(31);
    struct_words[1].values.push_back(41);
    check("fixed signal array of structs keeps plain queues independent",
          struct_words[0].values[0] == 31 &&
          struct_words[1].values[0] == 41);

    prediction = holder.pred[1].pop_front();
    holder.mem[-1].delete();
    holder.items[1].delete();
    holder.multi[0][4].delete();
    holder.real_values[0].delete();
    holder.real_values[1].delete();
    holder.string_values[0].delete();
    holder.string_values[1].delete();
    holder.nested_values[0].delete();
    check("inner queue deletion",
          holder.pred[1].size() == 0 && holder.mem[-1].size() == 0 &&
          holder.items[1].size() == 0 && holder.multi[0][4].size() == 0);

    if (failed)
      $fatal(1, "fixed-array container property checks failed");
    $display("PASSED");
  end
endmodule
