// IEEE 1800-2017/2023 15.4.5-15.4.8: mailbox get/peek/try_get/try_peek take
// a valid left-hand expression by ref. Section 13.5.2 requires captured
// queue, dynamic-array, and associative-array elements to survive as
// outdated refs if removed while a blocking access is parked. A failed try
// leaves its target unchanged because no message is retrieved or copied.
class mailbox_ref_item;
  int payload;
endclass

class mailbox_ref_holder;
  int value;
  int int_map [int];
  int string_map [string];
  int values [$];
endclass

class mailbox_ref_key;
  int id;
endclass

module sv_mailbox_ref_output_lvalue;
  mailbox #(int) mi;
  mailbox #(string) ms;
  mailbox #(real) mr;
  mailbox #(mailbox_ref_item) mo;
  mailbox #(bit) mb;
  mailbox #(bit [3:0]) mn;

  int scalar;
  string text;
  real real_value;
  mailbox_ref_item object_in;
  mailbox_ref_item object_out;
  int fixed [2];
  int dynamic_array [];
  int queue [$];
  int replaced_queue [$];
  int int_map [int];
  int replacement_map [int];
  int string_map [string];
  int object_map [mailbox_ref_key];
  bit [15:0] packed_value;
  bit bit_value;
  bit [3:0] nibble;
  mailbox_ref_holder holder0;
  mailbox_ref_holder holder1;
  mailbox_ref_holder selected_holder;
  mailbox_ref_key key0;
  mailbox_ref_key key1;
  mailbox_ref_key selected_object_key;
  int selected_index;
  string selected_string_key;
  int int_key_calls;
  int string_key_calls;
  int object_key_calls;
  bit holder_done;
  bit index_done;
  bit assoc_done;
  bit ok;
  bit failed;

  function automatic int capture_int_key();
    int_key_calls++;
    return selected_index;
  endfunction

  function automatic string capture_string_key();
    string_key_calls++;
    return selected_string_key;
  endfunction

  function automatic mailbox_ref_key capture_object_key();
    object_key_calls++;
    return selected_object_key;
  endfunction

  task check(string label, bit condition);
    if (!condition) begin
      $display("FAILED -- %0s", label);
      failed = 1;
    end
  endtask

  initial begin
    mi = new();
    ms = new();
    mr = new();
    mo = new();
    mb = new();
    mn = new();
    dynamic_array = new[2];
    queue = '{-1, -1};
    holder0 = new();
    holder1 = new();
    key0 = new();
    key0.id = 0;
    key1 = new();
    key1.id = 1;

    // Direct scalar/string/real/class-handle destinations.
    mi.put(11);
    scalar = -1;
    mi.get(scalar);
    check("direct scalar", scalar == 11);

    ms.put("message");
    text = "unchanged";
    ms.get(text);
    check("direct string", text == "message");

    mr.put(2.5);
    real_value = -1.0;
    ok = mr.try_get(real_value);
    check("direct real", ok && real_value == 2.5);

    object_in = new();
    object_in.payload = 19;
    mo.put(object_in);
    object_out = null;
    mo.peek(object_out);
    check("direct object peek",
          object_out != null && object_out.payload == 19);
    object_out = null;
    mo.get(object_out);
    check("direct object get",
          object_out != null && object_out.payload == 19);

    // Packed bit and part selections are read-modify-write targets.
    packed_value = 16'ha55a;
    bit_value = 0;
    mb.put(bit_value);
    mb.get(packed_value[1]);
    check("packed bit RMW", packed_value == 16'ha558);
    nibble = 4'h3;
    mn.put(nibble);
    ok = mn.try_get(packed_value[11:8]);
    // a558 (left by the preceding bit RMW) with [11:8] replaced by 3.
    check("packed part RMW", ok && packed_value == 16'ha358);

    // Class property, fixed word, dynamic-array element and queue element.
    holder0.value = -1;
    mi.put(31);
    mi.get(holder0.value);
    check("class property", holder0.value == 31);

    fixed[0] = -1;
    fixed[1] = -1;
    mi.put(37);
    ok = mi.try_get(fixed[1]);
    check("fixed array word", ok && fixed[1] == 37);

    dynamic_array[0] = -1;
    dynamic_array[1] = -1;
    mi.put(41);
    ok = mi.try_get(dynamic_array[1]);
    check("dynamic array element", ok && dynamic_array[1] == 41);

    mi.put(43);
    ok = mi.try_peek(queue[1]);
    check("queue element", ok && queue[1] == 43);
    mi.get(scalar);

    // Statement-position try methods use the same writeback path.
    mi.try_put(47);
    mi.try_get(queue[0]);
    check("statement try success", queue[0] == 47);

    scalar = 101;
    mi.try_get(scalar);
    check("failed statement try_get", scalar == 101);
    mi.try_peek(scalar);
    check("failed statement try_peek", scalar == 101);
    ok = mi.try_get(scalar);
    check("failed expression try_get", !ok && scalar == 101);
    ok = mi.try_peek(scalar);
    check("failed expression try_peek", !ok && scalar == 101);

    // The receiver object is captured before get blocks. Reassigning the
    // source handle while parked must not retarget the ref output.
    holder0.value = -1;
    holder1.value = -1;
    selected_holder = holder0;
    holder_done = 0;
    fork
      begin
        mi.get(selected_holder.value);
        holder_done = 1;
      end
    join_none
    #1;
    selected_holder = holder1;
    mi.put(53);
    wait (holder_done);
    check("blocked receiver capture",
          holder0.value == 53 && holder1.value == -1);

    // Likewise, a fixed-array word index is evaluated and captured once,
    // before peek parks. The peeked message remains available for get.
    fixed[0] = -1;
    fixed[1] = -1;
    selected_index = 0;
    index_done = 0;
    fork
      begin
        mi.peek(fixed[selected_index]);
        index_done = 1;
      end
    join_none
    #1;
    selected_index = 1;
    mi.put(59);
    wait (index_done);
    check("blocked index capture", fixed[0] == 59 && fixed[1] == -1);
    mi.get(scalar);
    check("peek retained item", scalar == 59 && mi.num() == 0);

    // The index expression of an associative element is evaluated exactly
    // once before blocking. An ordinary write to the same live element does
    // not detach the captured ref, and the resumed get updates that element.
    int_map[3] = -1;
    selected_index = 3;
    int_key_calls = 0;
    assoc_done = 0;
    fork
      begin
        mi.get(int_map[capture_int_key()]);
        assoc_done = 1;
      end
    join_none
    #1;
    selected_index = 4;
    int_map[3] = 71;
    mi.put(73);
    wait (assoc_done);
    check("blocked integral associative key capture",
          int_key_calls == 1 && int_map[3] == 73 && !int_map.exists(4));

    // Deleting the selected element detaches the old ref. Reinserting the
    // same key creates a distinct element that resumed writeback must not
    // overwrite (13.5.2 outdated-reference semantics).
    int_map[5] = -1;
    selected_index = 5;
    int_key_calls = 0;
    assoc_done = 0;
    fork
      begin
        mi.get(int_map[capture_int_key()]);
        assoc_done = 1;
      end
    join_none
    #1;
    int_map.delete(5);
    int_map[5] = 79;
    mi.put(83);
    wait (assoc_done);
    check("deleted associative element stays outdated",
          int_key_calls == 1 && int_map[5] == 79);

    // String keys use their own value stack but have the same capture rule.
    string_map["left"] = -1;
    selected_string_key = "left";
    string_key_calls = 0;
    assoc_done = 0;
    fork
      begin
        mi.get(string_map[capture_string_key()]);
        assoc_done = 1;
      end
    join_none
    #1;
    selected_string_key = "right";
    mi.put(89);
    wait (assoc_done);
    check("blocked string associative key capture",
          string_key_calls == 1 && string_map["left"] == 89
          && !string_map.exists("right"));

    // Associative-array class properties capture both receiver and key.
    holder0.int_map[7] = -1;
    holder1.int_map[7] = -1;
    selected_holder = holder0;
    selected_index = 7;
    assoc_done = 0;
    fork
      begin
        mi.get(selected_holder.int_map[selected_index]);
        assoc_done = 1;
      end
    join_none
    #1;
    selected_holder = holder1;
    selected_index = 8;
    mi.put(97);
    wait (assoc_done);
    check("associative property receiver capture",
          holder0.int_map[7] == 97 && holder1.int_map[7] == -1
          && selected_holder == holder1);

    holder0.string_map["before"] = -1;
    selected_holder = holder0;
    selected_string_key = "before";
    string_key_calls = 0;
    assoc_done = 0;
    fork
      begin
        mi.get(selected_holder.string_map[capture_string_key()]);
        assoc_done = 1;
      end
    join_none
    #1;
    selected_string_key = "after";
    mi.put(101);
    wait (assoc_done);
    check("string-key associative property capture",
          string_key_calls == 1 && holder0.string_map["before"] == 101
          && !holder0.string_map.exists("after"));

    // Object keys are captured as handles. Reassigning the key expression's
    // source variable cannot retarget the pending writeback.
    object_map[key0] = -1;
    object_map[key1] = -1;
    selected_object_key = key0;
    object_key_calls = 0;
    assoc_done = 0;
    fork
      begin
        mi.get(object_map[capture_object_key()]);
        assoc_done = 1;
      end
    join_none
    #1;
    selected_object_key = key1;
    mi.put(103);
    wait (assoc_done);
    check("object associative key capture",
          object_key_calls == 1 && object_map[key0] == 103
          && object_map[key1] == -1);

    // Whole-container replacement makes a positional element ref outdated.
    // The resumed get must not restore the old queue through stale provenance.
    replaced_queue = '{1};
    assoc_done = 0;
    fork
      begin
        mi.get(replaced_queue[0]);
        assoc_done = 1;
      end
    join_none
    #1;
    replaced_queue = '{2};
    mi.put(107);
    wait (assoc_done);
    check("whole queue replacement detaches output ref",
          replaced_queue.size() == 1 && replaced_queue[0] == 2);

    dynamic_array = new[1];
    dynamic_array[0] = 3;
    assoc_done = 0;
    fork
      begin
        mi.get(dynamic_array[0]);
        assoc_done = 1;
      end
    join_none
    #1;
    dynamic_array = new[1];
    dynamic_array[0] = 5;
    mi.put(131);
    wait (assoc_done);
    check("whole dynamic-array replacement detaches output ref",
          dynamic_array.size() == 1 && dynamic_array[0] == 5);

    int_map[11] = -1;
    replacement_map.delete();
    replacement_map[11] = 137;
    assoc_done = 0;
    fork
      begin
        mi.get(int_map[11]);
        assoc_done = 1;
      end
    join_none
    #1;
    int_map = replacement_map;
    mi.put(139);
    wait (assoc_done);
    check("whole associative replacement detaches output ref",
          int_map[11] == 137);

    // Changing the receiver variable does not detach a live property element;
    // replacing the selected property container itself does.
    holder0.values = '{-1};
    holder1.values = '{-1};
    selected_holder = holder0;
    assoc_done = 0;
    fork
      begin
        mi.get(selected_holder.values[0]);
        assoc_done = 1;
      end
    join_none
    #1;
    selected_holder = holder1;
    mi.put(109);
    wait (assoc_done);
    check("queue property receiver capture",
          holder0.values[0] == 109 && holder1.values[0] == -1
          && selected_holder == holder1);

    holder0.values = '{-1};
    selected_holder = holder0;
    assoc_done = 0;
    fork
      begin
        mi.get(selected_holder.values[0]);
        assoc_done = 1;
      end
    join_none
    #1;
    holder0.values = '{113};
    mi.put(127);
    wait (assoc_done);
    check("whole queue property replacement detaches output ref",
          holder0.values.size() == 1 && holder0.values[0] == 113);

    if (!failed)
      $display("PASSED");
  end
endmodule
