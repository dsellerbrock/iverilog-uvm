// IEEE 1800-2017 7.12.1: class-handle array elements compare by handle
// identity. A with clause may instead produce any type for which equality is
// defined. Result order and the representative selected for an equal key are
// unspecified, so these checks are set based.
class unique_node;
  int tag;
  logic [71:0] wide_key;
  real real_key;
  string text_key;
  unique_node object_key;

  function new(input int value);
    tag = value;
  endfunction

  // Preserve the two legal method-call key shapes that previously lived in
  // the residual expected-failure test.
  virtual function bit [31:0] unsigned_key();
    return (tag + 1) / 2;
  endfunction

  virtual function string string_key();
    return text_key;
  endfunction
endclass

module main;
  unique_node a;
  unique_node b;
  unique_node c;
  unique_node d;
  unique_node e;
  unique_node f;
  unique_node key_a;
  unique_node key_b;

  unique_node plain_queue[$];
  unique_node plain_dynamic[];
  unique_node keyed_queue[$];
  unique_node keyed_dynamic[];
  unique_node never_allocated[];
  unique_node result[$];
  unique_node represented[$];
  int indexes[$];
  bit failed;

  task automatic check(input string label, input logic ok);
    if (ok !== 1'b1) begin
      $display("FAILED -- %0s", label);
      failed = 1'b1;
    end
  endtask

  function automatic bit is_plain_member(input unique_node value);
    return value == null || value == a || value == b || value == c;
  endfunction

  task automatic check_plain_values(input string label,
                                    input unique_node got[$]);
    bit seen_null;
    bit seen_a;
    bit seen_b;
    bit seen_c;
    int i;
    seen_null = 1'b0;
    seen_a = 1'b0;
    seen_b = 1'b0;
    seen_c = 1'b0;
    check(label, got.size() == 4);
    for (i = 0; i < got.size(); i = i + 1) begin
      check("plain result is an original handle", is_plain_member(got[i]));
      if (got[i] == null) begin
        check("one null handle", !seen_null); seen_null = 1'b1;
      end else if (got[i] == a) begin
        check("one a handle", !seen_a); seen_a = 1'b1;
      end else if (got[i] == b) begin
        check("one b handle", !seen_b); seen_b = 1'b1;
      end else if (got[i] == c) begin
        check("one c handle", !seen_c); seen_c = 1'b1;
      end
    end
    check(label, seen_null && seen_a && seen_b && seen_c);
  endtask

  task automatic check_plain_queue_indexes(input string label,
                                           input int got[$]);
    int i;
    represented.delete();
    for (i = 0; i < got.size(); i = i + 1) begin
      check("plain queue index range",
            got[i] >= 0 && got[i] < plain_queue.size());
      if (got[i] >= 0 && got[i] < plain_queue.size())
        represented.push_back(plain_queue[got[i]]);
    end
    check_plain_values(label, represented);
  endtask

  task automatic check_plain_dynamic_indexes(input string label,
                                             input int got[$]);
    int i;
    represented.delete();
    for (i = 0; i < got.size(); i = i + 1) begin
      check("plain dynamic index range",
            got[i] >= 0 && got[i] < plain_dynamic.size());
      if (got[i] >= 0 && got[i] < plain_dynamic.size())
        represented.push_back(plain_dynamic[got[i]]);
    end
    check_plain_values(label, represented);
  endtask

  function automatic bit is_keyed_member(input unique_node value);
    return value == a || value == b || value == c
           || value == d || value == e || value == f;
  endfunction

  task automatic check_wide_values(input string label,
                                   input unique_node got[$]);
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
      check("wide result is an original handle", is_keyed_member(got[i]));
      if (got[i].wide_key === 72'h010000000000000001) begin
        check("one wide A key", !seen_a); seen_a = 1'b1;
      end else if (got[i].wide_key === 72'h020000000000000001) begin
        check("one wide B key", !seen_b); seen_b = 1'b1;
      end else if (got[i].wide_key === 72'h03000000000000000x) begin
        check("one wide X key", !seen_x); seen_x = 1'b1;
      end else if (got[i].wide_key === 72'h03000000000000000z) begin
        check("one wide Z key", !seen_z); seen_z = 1'b1;
      end else begin
        check("unexpected wide key", 1'b0);
      end
    end
    check(label, seen_a && seen_b && seen_x && seen_z);
  endtask

  task automatic check_wide_indexes(input string label, input int got[$]);
    int i;
    represented.delete();
    for (i = 0; i < got.size(); i = i + 1) begin
      check("wide key index range",
            got[i] >= 0 && got[i] < keyed_queue.size());
      if (got[i] >= 0 && got[i] < keyed_queue.size())
        represented.push_back(keyed_queue[got[i]]);
    end
    check_wide_values(label, represented);
  endtask

  task automatic check_unsigned_method_values(input string label,
                                               input unique_node got[$]);
    bit seen_one;
    bit seen_two;
    bit seen_three;
    int i;
    seen_one = 1'b0;
    seen_two = 1'b0;
    seen_three = 1'b0;
    check(label, got.size() == 3);
    for (i = 0; i < got.size(); i = i + 1) begin
      check("unsigned-method result is an original handle",
            is_keyed_member(got[i]));
      if (got[i].unsigned_key() == 1) begin
        check("one unsigned method key 1", !seen_one); seen_one = 1'b1;
      end else if (got[i].unsigned_key() == 2) begin
        check("one unsigned method key 2", !seen_two); seen_two = 1'b1;
      end else if (got[i].unsigned_key() == 3) begin
        check("one unsigned method key 3", !seen_three); seen_three = 1'b1;
      end else begin
        check("unexpected unsigned method key", 1'b0);
      end
    end
    check(label, seen_one && seen_two && seen_three);
  endtask

  task automatic check_unsigned_method_indexes(input string label,
                                                input int got[$]);
    int i;
    represented.delete();
    for (i = 0; i < got.size(); i = i + 1) begin
      check("unsigned method index range",
            got[i] >= 0 && got[i] < keyed_queue.size());
      if (got[i] >= 0 && got[i] < keyed_queue.size())
        represented.push_back(keyed_queue[got[i]]);
    end
    check_unsigned_method_values(label, represented);
  endtask

  task automatic check_real_values(input string label,
                                   input unique_node got[$]);
    bit seen_one;
    bit seen_two;
    bit seen_three;
    int i;
    seen_one = 1'b0;
    seen_two = 1'b0;
    seen_three = 1'b0;
    check(label, got.size() == 3);
    for (i = 0; i < got.size(); i = i + 1) begin
      check("real result is an original handle", is_keyed_member(got[i]));
      if (got[i].real_key == 1.25) begin
        check("one real 1.25 key", !seen_one); seen_one = 1'b1;
      end else if (got[i].real_key == 2.5) begin
        check("one real 2.5 key", !seen_two); seen_two = 1'b1;
      end else if (got[i].real_key == 3.75) begin
        check("one real 3.75 key", !seen_three); seen_three = 1'b1;
      end else begin
        check("unexpected real key", 1'b0);
      end
    end
    check(label, seen_one && seen_two && seen_three);
  endtask

  task automatic check_real_indexes(input string label, input int got[$]);
    int i;
    represented.delete();
    for (i = 0; i < got.size(); i = i + 1) begin
      check("real key index range",
            got[i] >= 0 && got[i] < keyed_queue.size());
      if (got[i] >= 0 && got[i] < keyed_queue.size())
        represented.push_back(keyed_queue[got[i]]);
    end
    check_real_values(label, represented);
  endtask

  task automatic check_text_values(input string label,
                                   input unique_node got[$]);
    bit seen_red;
    bit seen_blue;
    bit seen_green;
    int i;
    seen_red = 1'b0;
    seen_blue = 1'b0;
    seen_green = 1'b0;
    check(label, got.size() == 3);
    for (i = 0; i < got.size(); i = i + 1) begin
      check("string result is an original handle", is_keyed_member(got[i]));
      if (got[i].text_key == "red") begin
        check("one red key", !seen_red); seen_red = 1'b1;
      end else if (got[i].text_key == "blue") begin
        check("one blue key", !seen_blue); seen_blue = 1'b1;
      end else if (got[i].text_key == "green") begin
        check("one green key", !seen_green); seen_green = 1'b1;
      end else begin
        check("unexpected string key", 1'b0);
      end
    end
    check(label, seen_red && seen_blue && seen_green);
  endtask

  task automatic check_text_indexes(input string label, input int got[$]);
    int i;
    represented.delete();
    for (i = 0; i < got.size(); i = i + 1) begin
      check("string key index range",
            got[i] >= 0 && got[i] < keyed_dynamic.size());
      if (got[i] >= 0 && got[i] < keyed_dynamic.size())
        represented.push_back(keyed_dynamic[got[i]]);
    end
    check_text_values(label, represented);
  endtask

  task automatic check_text_queue_indexes(input string label,
                                           input int got[$]);
    int i;
    represented.delete();
    for (i = 0; i < got.size(); i = i + 1) begin
      check("string method index range",
            got[i] >= 0 && got[i] < keyed_queue.size());
      if (got[i] >= 0 && got[i] < keyed_queue.size())
        represented.push_back(keyed_queue[got[i]]);
    end
    check_text_values(label, represented);
  endtask

  task automatic check_object_key_values(input string label,
                                         input unique_node got[$]);
    bit seen_a;
    bit seen_b;
    bit seen_null;
    int i;
    seen_a = 1'b0;
    seen_b = 1'b0;
    seen_null = 1'b0;
    check(label, got.size() == 3);
    for (i = 0; i < got.size(); i = i + 1) begin
      check("object-key result is an original handle",
            is_keyed_member(got[i]));
      if (got[i].object_key == key_a) begin
        check("one object key A", !seen_a); seen_a = 1'b1;
      end else if (got[i].object_key == key_b) begin
        check("one object key B", !seen_b); seen_b = 1'b1;
      end else if (got[i].object_key == null) begin
        check("one null object key", !seen_null); seen_null = 1'b1;
      end else begin
        check("unexpected object key", 1'b0);
      end
    end
    check(label, seen_a && seen_b && seen_null);
  endtask

  task automatic check_object_key_indexes(input string label,
                                          input int got[$]);
    int i;
    represented.delete();
    for (i = 0; i < got.size(); i = i + 1) begin
      check("object key index range",
            got[i] >= 0 && got[i] < keyed_dynamic.size());
      if (got[i] >= 0 && got[i] < keyed_dynamic.size())
        represented.push_back(keyed_dynamic[got[i]]);
    end
    check_object_key_values(label, represented);
  endtask

  initial begin
    failed = 1'b0;
    key_a = new(100);
    key_b = new(101);
    a = new(1);
    b = new(2);
    c = new(3);
    d = new(4);
    e = new(5);
    f = new(6);

    a.wide_key = 72'h010000000000000001;
    b.wide_key = 72'h020000000000000001;
    c.wide_key = 72'h010000000000000001;
    d.wide_key = 72'h03000000000000000x;
    e.wide_key = 72'h03000000000000000x;
    f.wide_key = 72'h03000000000000000z;
    a.real_key = 1.25; b.real_key = 2.5; c.real_key = 3.75;
    d.real_key = 1.25; e.real_key = 2.5; f.real_key = 3.75;
    a.text_key = "red"; b.text_key = "red";
    c.text_key = "blue"; d.text_key = "green";
    e.text_key = "blue"; f.text_key = "green";
    a.object_key = key_a; b.object_key = key_b; c.object_key = key_a;
    d.object_key = null; e.object_key = null; f.object_key = key_b;

    plain_queue = '{a, b, a, null, c, b, null};
    result = plain_queue.unique;
    check_plain_values("plain class queue unique", result);
    indexes = plain_queue.unique_index;
    check_plain_queue_indexes("plain class queue unique_index", indexes);

    plain_dynamic = new[7];
    plain_dynamic[0] = a; plain_dynamic[1] = b;
    plain_dynamic[2] = a; plain_dynamic[3] = null;
    plain_dynamic[4] = c; plain_dynamic[5] = b;
    plain_dynamic[6] = null;
    result = plain_dynamic.unique();
    check_plain_values("plain class dynamic-array unique", result);
    indexes = plain_dynamic.unique_index();
    check_plain_dynamic_indexes("plain class dynamic-array unique_index",
                                indexes);

    result = never_allocated.unique;
    indexes = never_allocated.unique_index;
    check("null class dynamic array returns typed empty queues",
          result.size() == 0 && indexes.size() == 0);
    result.push_back(a);
    check("empty class unique result is fresh", result.size() == 1);

    keyed_queue = '{a, b, c, d, e, f};
    result = keyed_queue.unique(node) with (node.wide_key);
    check_wide_values("class iterator with full-width four-state key", result);
    indexes = keyed_queue.unique_index(node) with (node.wide_key);
    check_wide_indexes("class unique_index with four-state key", indexes);

    result = keyed_queue.unique(node) with (node.real_key);
    check_real_values("class iterator with real key", result);
    indexes = keyed_queue.unique_index(node) with (node.real_key);
    check_real_indexes("class unique_index with real key", indexes);

    result = keyed_queue.unique(node) with (node.unsigned_key);
    check_unsigned_method_values("class iterator with unsigned method key",
                                 result);
    indexes = keyed_queue.unique_index(node) with (node.unsigned_key);
    check_unsigned_method_indexes(
          "class unique_index with unsigned method key", indexes);
    result = keyed_queue.unique(node) with (node.string_key);
    check_text_values("class iterator with string method key", result);
    indexes = keyed_queue.unique_index(node) with (node.string_key);
    check_text_queue_indexes("class unique_index with string method key",
                             indexes);

    keyed_dynamic = new[6];
    keyed_dynamic[0] = a; keyed_dynamic[1] = b;
    keyed_dynamic[2] = c; keyed_dynamic[3] = d;
    keyed_dynamic[4] = e; keyed_dynamic[5] = f;
    result = keyed_dynamic.unique(node) with (node.text_key);
    check_text_values("class iterator with string key", result);
    indexes = keyed_dynamic.unique_index(node) with (node.text_key);
    check_text_indexes("class unique_index with string key", indexes);

    result = keyed_dynamic.unique(node) with (node.object_key);
    check_object_key_values("class iterator with class-handle key", result);
    indexes = keyed_dynamic.unique_index(node) with (node.object_key);
    check_object_key_indexes("class unique_index with class-handle key",
                             indexes);

    check("source queue remains unchanged",
          plain_queue.size() == 7 && plain_queue[0] == a
          && plain_queue[2] == a && plain_queue[3] == null);
    check("source dynamic array remains unchanged",
          keyed_dynamic.size() == 6 && keyed_dynamic[0] == a
          && keyed_dynamic[5] == f);

    if (failed)
      $fatal(1, "class-handle unique checks failed");
    $display("PASSED");
  end
endmodule
