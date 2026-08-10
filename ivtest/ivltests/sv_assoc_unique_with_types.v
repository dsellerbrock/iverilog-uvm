// Associative unique comparison queues must preserve wide four-state values,
// real/string values, class-handle identity, and exact string/class indexes.
class assoc_group;
  int id;
  function new(input int value);
    id = value;
  endfunction
endclass

class assoc_entry;
  assoc_group group;
  int payload;
  function new(input assoc_group g, input int value);
    group = g;
    payload = value;
  endfunction
endclass

module main;
  typedef logic [79:0] wide_index_t;

  bit failed;

  logic [71:0] wide_values[int];
  logic [71:0] wide_result[$];
  int wide_indexes[$];

  int wide_index_values[wide_index_t];
  wide_index_t wide_key_indexes[$];

  real real_values[string];
  real real_result[$];
  string real_indexes[$];
  string every_string_index[$];

  string text_values[int];
  string text_result[$];

  assoc_entry object_values[string];
  assoc_entry object_plain_result[$];
  assoc_entry object_result[$];
  string object_indexes[$];
  assoc_group group_a;
  assoc_group group_b;
  assoc_entry entry_a1;
  assoc_entry entry_a2;
  assoc_entry entry_b;

  int class_index_values[assoc_group];
  assoc_group class_indexes[$];
  assoc_group every_class_index[$];
  assoc_group group_c;

  task automatic check(input string label, input logic ok);
    if (ok !== 1'b1) begin
      $display("FAILED -- %0s", label);
      failed = 1'b1;
    end
  endtask

  task automatic check_wide(input string label,
                             input logic [71:0] got[$]);
    bit seen_a;
    bit seen_b;
    bit seen_x;
    bit seen_z;
    int i;
    seen_a = 0; seen_b = 0; seen_x = 0; seen_z = 0;
    check(label, got.size() == 4);
    for (i = 0; i < got.size(); i = i + 1) begin
      if (got[i] === 72'h010000000000000001) begin
        check("one wide A", !seen_a); seen_a = 1;
      end else if (got[i] === 72'h020000000000000001) begin
        check("one wide B", !seen_b); seen_b = 1;
      end else if (got[i] === 72'h03000000000000000x) begin
        check("one wide X", !seen_x); seen_x = 1;
      end else if (got[i] === 72'h03000000000000000z) begin
        check("one wide Z", !seen_z); seen_z = 1;
      end else begin
        check("wide member", 0);
      end
    end
    check(label, seen_a && seen_b && seen_x && seen_z);
  endtask

  initial begin
    int i;
    logic [71:0] represented_wide[$];
    bit seen_neg;
    bit seen_one;
    bit seen_two;
    bit seen_red;
    bit seen_blue;
    bit seen_group_a;
    bit seen_group_b;
    bit seen_seven;
    bit seen_nine;
    bit seen_wide_one;
    bit seen_wide_two;

    failed = 1'b0;

    wide_values[10] = 72'h010000000000000001;
    wide_values[20] = 72'h020000000000000001;
    wide_values[30] = 72'h010000000000000001;
    wide_values[40] = 72'h03000000000000000x;
    wide_values[50] = 72'h03000000000000000x;
    wide_values[60] = 72'h03000000000000000z;
    wide_result = wide_values.unique(v) with (v);
    wide_indexes = wide_values.unique_index(v) with (v);
    check_wide("wide/X/Z comparison values", wide_result);
    for (i = 0; i < wide_indexes.size(); i = i + 1) begin
      check("wide returned index exists", wide_values.exists(wide_indexes[i]));
      if (wide_values.exists(wide_indexes[i]))
        represented_wide.push_back(wide_values[wide_indexes[i]]);
    end
    check_wide("wide/X/Z comparison indexes", represented_wide);

    wide_index_values[80'h01000000000000000001] = 44;
    wide_index_values[80'h02000000000000000002] = 44;
    wide_index_values[80'hff000000000000000003] = 55;
    wide_key_indexes = wide_index_values.unique_index;
    check("wide integral exact index result", wide_key_indexes.size() == 2);
    seen_wide_one = 0; seen_wide_two = 0;
    for (i = 0; i < wide_key_indexes.size(); i = i + 1) begin
      check("wide integral returned index exists",
            wide_index_values.exists(wide_key_indexes[i]));
      if (wide_index_values.exists(wide_key_indexes[i])) begin
        if (wide_index_values[wide_key_indexes[i]] == 44)
          seen_wide_one = 1;
        else if (wide_index_values[wide_key_indexes[i]] == 55)
          seen_wide_two = 1;
        else
          check("wide integral index representative", 0);
      end
    end
    check("wide integral index groups", seen_wide_one && seen_wide_two);

    real_values["neg"] = -3.5;
    real_values["one-a"] = 1.25;
    real_values["one-b"] = 1.25;
    real_values["two"] = 2.5;
    real_result = real_values.unique(v) with (v);
    real_indexes = real_values.unique_index(v) with (v);
    check("real comparison value size", real_result.size() == 3);
    check("real comparison exact string index type", real_indexes.size() == 3);
    seen_neg = 0; seen_one = 0; seen_two = 0;
    for (i = 0; i < real_indexes.size(); i = i + 1) begin
      check("real returned string index exists",
            real_values.exists(real_indexes[i]));
      if (real_values.exists(real_indexes[i])) begin
        if (real_values[real_indexes[i]] == -3.5) seen_neg = 1;
        else if (real_values[real_indexes[i]] == 1.25) seen_one = 1;
        else if (real_values[real_indexes[i]] == 2.5) seen_two = 1;
        else check("real representative", 0);
      end
    end
    check("all real groups", seen_neg && seen_one && seen_two);
    every_string_index = real_values.unique_index(v) with (v.index());
    check("string iterator index() type", every_string_index.size() == 4);

    text_values[1] = "Red";
    text_values[2] = "red";
    text_values[3] = "Blue";
    text_result = text_values.unique(v) with (v.tolower());
    check("string comparison size", text_result.size() == 2);
    seen_red = 0; seen_blue = 0;
    for (i = 0; i < text_result.size(); i = i + 1) begin
      if (text_result[i].tolower() == "red") seen_red = 1;
      else if (text_result[i].tolower() == "blue") seen_blue = 1;
      else check("string comparison representative", 0);
    end
    check("all string comparison groups", seen_red && seen_blue);

    group_a = new(1);
    group_b = new(2);
    group_c = new(3);
    entry_a1 = new(group_a, 100);
    entry_a2 = new(group_a, 200);
    entry_b = new(group_b, 300);
    object_values["a1"] = entry_a1;
    object_values["a1-duplicate"] = entry_a1;
    object_values["a2"] = entry_a2;
    object_values["b"] = entry_b;
    object_plain_result = object_values.unique;
    object_result = object_values.unique(v) with (v.group);
    object_indexes = object_values.unique_index(v) with (v.group);
    check("plain object-handle identity", object_plain_result.size() == 3);
    check("object comparison values", object_result.size() == 2);
    check("object comparison string indexes", object_indexes.size() == 2);
    seen_group_a = 0; seen_group_b = 0;
    for (i = 0; i < object_result.size(); i = i + 1) begin
      if (object_result[i].group == group_a) seen_group_a = 1;
      else if (object_result[i].group == group_b) seen_group_b = 1;
      else check("object comparison representative", 0);
    end
    check("object handle identity groups", seen_group_a && seen_group_b);

    class_index_values[group_a] = 7;
    class_index_values[group_b] = 7;
    class_index_values[group_c] = 9;
    class_indexes = class_index_values.unique_index;
    check("class-handle exact index result type", class_indexes.size() == 2);
    seen_seven = 0; seen_nine = 0;
    for (i = 0; i < class_indexes.size(); i = i + 1) begin
      check("class returned index exists",
            class_index_values.exists(class_indexes[i]));
      if (class_index_values.exists(class_indexes[i])) begin
        if (class_index_values[class_indexes[i]] == 7) seen_seven = 1;
        else if (class_index_values[class_indexes[i]] == 9) seen_nine = 1;
        else check("class index representative", 0);
      end
    end
    check("all class-index groups", seen_seven && seen_nine);
    every_class_index = class_index_values.unique_index(v) with (v.index());
    check("class iterator index() type and object comparison",
          every_class_index.size() == 3);

    if (failed)
      $display("FAILED");
    else
      $display("PASSED");
  end
endmodule
