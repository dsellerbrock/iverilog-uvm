// IEEE 1800-2017 7.12.1: unique(iterator) with (key) returns a fresh
// queue containing one original element handle for each distinct key.
// This mirrors uvm_callback.svh's CB[$].unique(cb_) with
// (cb_.get_inst_id) use without modifying the UVM source.
class callback_base;
  int base_id;
  int payload;

  function new(input int id, input int data);
    base_id = id;
    payload = data;
  endfunction

  virtual function int get_inst_id();
    return base_id;
  endfunction
endclass

class callback_derived extends callback_base;
  int derived_id;

  function new(input int base_value, input int key, input int data);
    super.new(base_value, data);
    derived_id = key;
  endfunction

  virtual function int get_inst_id();
    return derived_id;
  endfunction
endclass

class callback_collection;
  static function void collect(
      input callback_base callbacks_to_append[$],
      output callback_base unique_callbacks_to_append[$]);
    callback_base cb_;
    unique_callbacks_to_append =
        callbacks_to_append.unique(cb_) with (cb_.get_inst_id);
  endfunction
endclass

module main;
  callback_base source[$];
  callback_base result_a[$];
  callback_base result_b[$];
  callback_base default_result[$];
  callback_base empty_source[$];
  callback_base empty_results[$][$];
  callback_base a;
  callback_base b;
  callback_base c;
  callback_base d;
  callback_base e;
  callback_base extra;
  callback_derived b_impl;
  callback_derived d_impl;
  bit failed;

  task automatic check(input string label, input logic ok);
    if (ok !== 1'b1) begin
      $display("FAILED -- %0s", label);
      failed = 1'b1;
    end
  endtask

  task automatic check_source(input string label);
    check(label, source.size() == 6
          && source[0] == a && source[1] == b && source[2] == c
          && source[3] == a && source[4] == d && source[5] == e);
  endtask

  task automatic check_result(input string label,
                              input callback_base got[$]);
    bit seen_7;
    bit seen_9;
    bit seen_11;
    int i;
    int key;
    seen_7 = 1'b0;
    seen_9 = 1'b0;
    seen_11 = 1'b0;
    check(label, got.size() == 3);
    for (i = 0; i < got.size(); i = i + 1) begin
      check("result handle is non-null", got[i] != null);
      check("result retains an original handle",
            got[i] == a || got[i] == b || got[i] == c
            || got[i] == d || got[i] == e);
      key = got[i].get_inst_id();
      case (key)
        7: begin check("one key 7", !seen_7); seen_7 = 1'b1; end
        9: begin check("one key 9", !seen_9); seen_9 = 1'b1; end
        11: begin check("one key 11", !seen_11); seen_11 = 1'b1; end
        default: check("unexpected key", 1'b0);
      endcase
    end
    check("all keys retained", seen_7 && seen_9 && seen_11);
  endtask

  initial begin
    failed = 1'b0;
    a = new(7, 100);
    b_impl = new(99, 9, 200);
    b = b_impl;
    c = new(7, 300);
    d_impl = new(98, 11, 400);
    d = d_impl;
    e = new(9, 500);
    extra = new(13, 600);
    source = '{a, b, c, a, d, e};

    callback_collection::collect(source, result_a);
    callback_collection::collect(source, result_b);
    check_result("exact UVM-shaped call", result_a);
    check_result("each call returns a complete result", result_b);
    check_source("source unchanged after expression calls");

    void'(result_a.pop_back());
    result_a.push_back(extra);
    check("result containers do not alias", result_b.size() == 3);
    check_source("result mutation does not mutate source");

    result_b[0].payload = 777;
    check("returned elements retain handle identity",
          (result_b[0] == a && a.payload == 777)
          || (result_b[0] == b && b.payload == 777)
          || (result_b[0] == c && c.payload == 777)
          || (result_b[0] == d && d.payload == 777)
          || (result_b[0] == e && e.payload == 777));

    default_result = source.unique() with (item.get_inst_id());
    check_result("default iterator call", default_result);
    default_result = source.unique with (item.get_inst_id);
    check_result("parenless default iterator call", default_result);

    source.unique with (item.get_inst_id);
    check_source("discarded results leave source unchanged");

    empty_results.push_back(
        empty_source.unique(cb_) with (cb_.get_inst_id));
    empty_results.push_back(
        empty_source.unique(cb_) with (cb_.get_inst_id));
    check("empty calls return distinct empty containers",
          empty_results.size() == 2
          && empty_results[0].size() == 0
          && empty_results[1].size() == 0
          && empty_source.size() == 0);
    empty_results[0].push_back(a);
    check("empty result is a fresh usable queue",
          empty_results[0].size() == 1
          && empty_results[1].size() == 0
          && empty_source.size() == 0);

    if (failed)
      $fatal(1, "unique-with object checks failed");
    $display("PASSED");
  end
endmodule
