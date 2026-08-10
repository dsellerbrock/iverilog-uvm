// IEEE 1800-2017 7.12.1: unique()/unique_index() apply to every
// one-dimensional unpacked array. Fixed-array unique_index values and
// iterator.index are declared indexes, including descending and nonzero
// ranges. Result order and duplicate representatives are unspecified.
class fixed_unique_entry;
  int tag;
  int group;

  function new(input int value, input int key);
    tag = value;
    group = key;
  endfunction
endclass

class fixed_unique_holder;
  logic [7:0] bytes[3:6];
  real reals[9:6];
  string texts[-5:-2];
  fixed_unique_entry objects[30:27];
endclass

// Exact fixed-property receiver shape formerly kept as a residual failure.
class mailbox_sequence;
  bit [7:0] mbox_valid_users[6];
  bit [7:0] mbox_valid_users_uniq[$];

  function void build_users;
    mbox_valid_users_uniq = mbox_valid_users.unique;
  endfunction
endclass

module main;
  logic [7:0] direct_bytes[-2:1];
  real direct_reals[8:5];
  string direct_texts[11:14];
  string string_roundtrip[7:4];
  string string_dynamic[];
  fixed_unique_entry direct_objects[22:19];

  logic [7:0] byte_result[$];
  real real_result[$];
  string text_result[$];
  fixed_unique_entry object_result[$];
  int indexes[$];

  fixed_unique_entry a;
  fixed_unique_entry b;
  fixed_unique_entry c;
  fixed_unique_holder holder;
  mailbox_sequence seq;
  bit failed;

  task automatic check(input string label, input logic ok);
    if (ok !== 1'b1) begin
      $display("FAILED -- %0s", label);
      failed = 1'b1;
    end
  endtask

  task automatic check_byte_values(input string label,
                                   input logic [7:0] got[$],
                                   input bit keyed);
    bit seen_10;
    bit seen_11;
    bit seen_12;
    bit seen_even;
    bit seen_odd;
    int i;
    seen_10 = 1'b0;
    seen_11 = 1'b0;
    seen_12 = 1'b0;
    seen_even = 1'b0;
    seen_odd = 1'b0;
    check(label, got.size() == (keyed ? 2 : 3));
    for (i = 0; i < got.size(); i = i + 1) begin
      check("fixed byte result membership",
            got[i] == 8'd10 || got[i] == 8'd11 || got[i] == 8'd12);
      if (keyed) begin
        if (got[i][0]) begin
          check("one odd byte key", !seen_odd); seen_odd = 1'b1;
        end else begin
          check("one even byte key", !seen_even); seen_even = 1'b1;
        end
      end else if (got[i] == 8'd10) begin
        check("one byte 10", !seen_10); seen_10 = 1'b1;
      end else if (got[i] == 8'd11) begin
        check("one byte 11", !seen_11); seen_11 = 1'b1;
      end else if (got[i] == 8'd12) begin
        check("one byte 12", !seen_12); seen_12 = 1'b1;
      end
    end
    if (keyed)
      check(label, seen_even && seen_odd);
    else
      check(label, seen_10 && seen_11 && seen_12);
  endtask

  task automatic check_mailbox_values(input string label,
                                      input bit [7:0] got[$]);
    bit seen_10;
    bit seen_11;
    bit seen_12;
    int i;
    seen_10 = 1'b0;
    seen_11 = 1'b0;
    seen_12 = 1'b0;
    check(label, got.size() == 3);
    for (i = 0; i < got.size(); i = i + 1) begin
      if (got[i] == 8'd10) begin
        check("one mailbox byte 10", !seen_10); seen_10 = 1'b1;
      end else if (got[i] == 8'd11) begin
        check("one mailbox byte 11", !seen_11); seen_11 = 1'b1;
      end else if (got[i] == 8'd12) begin
        check("one mailbox byte 12", !seen_12); seen_12 = 1'b1;
      end else begin
        check("unexpected mailbox byte", 1'b0);
      end
    end
    check(label, seen_10 && seen_11 && seen_12);
  endtask

  task automatic check_real_values(input string label,
                                   input real got[$], input bit keyed);
    bit seen_one;
    bit seen_two;
    bit seen_three;
    bit seen_low;
    bit seen_high;
    int i;
    seen_one = 1'b0;
    seen_two = 1'b0;
    seen_three = 1'b0;
    seen_low = 1'b0;
    seen_high = 1'b0;
    check(label, got.size() == (keyed ? 2 : 3));
    for (i = 0; i < got.size(); i = i + 1) begin
      check("fixed real result membership",
            got[i] == 1.25 || got[i] == 2.5 || got[i] == 3.75);
      if (keyed) begin
        if (got[i] >= 2.0) begin
          check("one high real key", !seen_high); seen_high = 1'b1;
        end else begin
          check("one low real key", !seen_low); seen_low = 1'b1;
        end
      end else if (got[i] == 1.25) begin
        check("one real 1.25", !seen_one); seen_one = 1'b1;
      end else if (got[i] == 2.5) begin
        check("one real 2.5", !seen_two); seen_two = 1'b1;
      end else if (got[i] == 3.75) begin
        check("one real 3.75", !seen_three); seen_three = 1'b1;
      end
    end
    if (keyed)
      check(label, seen_low && seen_high);
    else
      check(label, seen_one && seen_two && seen_three);
  endtask

  task automatic check_text_values(input string label,
                                   input string got[$], input bit keyed);
    bit seen_red;
    bit seen_blue;
    bit seen_green;
    bit seen_is_red;
    bit seen_not_red;
    int i;
    seen_red = 1'b0;
    seen_blue = 1'b0;
    seen_green = 1'b0;
    seen_is_red = 1'b0;
    seen_not_red = 1'b0;
    check(label, got.size() == (keyed ? 2 : 3));
    for (i = 0; i < got.size(); i = i + 1) begin
      check("fixed string result membership",
            got[i] == "red" || got[i] == "blue" || got[i] == "green");
      if (keyed) begin
        if (got[i] == "red") begin
          check("one red boolean key", !seen_is_red); seen_is_red = 1'b1;
        end else begin
          check("one non-red boolean key", !seen_not_red);
          seen_not_red = 1'b1;
        end
      end else if (got[i] == "red") begin
        check("one red string", !seen_red); seen_red = 1'b1;
      end else if (got[i] == "blue") begin
        check("one blue string", !seen_blue); seen_blue = 1'b1;
      end else if (got[i] == "green") begin
        check("one green string", !seen_green); seen_green = 1'b1;
      end
    end
    if (keyed)
      check(label, seen_is_red && seen_not_red);
    else
      check(label, seen_red && seen_blue && seen_green);
  endtask

  task automatic check_object_values(input string label,
                                     input fixed_unique_entry got[$],
                                     input bit keyed);
    bit seen_a;
    bit seen_b;
    bit seen_c;
    bit seen_one;
    bit seen_two;
    int i;
    seen_a = 1'b0;
    seen_b = 1'b0;
    seen_c = 1'b0;
    seen_one = 1'b0;
    seen_two = 1'b0;
    check(label, got.size() == (keyed ? 2 : 3));
    for (i = 0; i < got.size(); i = i + 1) begin
      check("fixed object result membership",
            got[i] == a || got[i] == b || got[i] == c);
      if (keyed) begin
        if (got[i].group == 1) begin
          check("one object group 1", !seen_one); seen_one = 1'b1;
        end else if (got[i].group == 2) begin
          check("one object group 2", !seen_two); seen_two = 1'b1;
        end else begin
          check("unexpected object group", 1'b0);
        end
      end else if (got[i] == a) begin
        check("one fixed object a", !seen_a); seen_a = 1'b1;
      end else if (got[i] == b) begin
        check("one fixed object b", !seen_b); seen_b = 1'b1;
      end else if (got[i] == c) begin
        check("one fixed object c", !seen_c); seen_c = 1'b1;
      end
    end
    if (keyed)
      check(label, seen_one && seen_two);
    else
      check(label, seen_a && seen_b && seen_c);
  endtask

  function automatic bit byte_index_valid(input bit property_source,
                                          input int index);
    return property_source ? (index >= 3 && index <= 6)
                           : (index >= -2 && index <= 1);
  endfunction

  function automatic logic [7:0] byte_at(input bit property_source,
                                         input int index);
    return property_source ? holder.bytes[index] : direct_bytes[index];
  endfunction

  task automatic check_byte_indexes(input string label, input int got[$],
                                    input bit property_source,
                                    input bit keyed);
    logic [7:0] values[$];
    int i;
    for (i = 0; i < got.size(); i = i + 1) begin
      check("fixed byte declared index",
            byte_index_valid(property_source, got[i]));
      if (byte_index_valid(property_source, got[i]))
        values.push_back(byte_at(property_source, got[i]));
    end
    check_byte_values(label, values, keyed);
  endtask

  function automatic bit real_index_valid(input bit property_source,
                                          input int index);
    return property_source ? (index >= 6 && index <= 9)
                           : (index >= 5 && index <= 8);
  endfunction

  function automatic real real_at(input bit property_source,
                                  input int index);
    return property_source ? holder.reals[index] : direct_reals[index];
  endfunction

  task automatic check_real_indexes(input string label, input int got[$],
                                    input bit property_source,
                                    input bit keyed);
    real values[$];
    int i;
    for (i = 0; i < got.size(); i = i + 1) begin
      check("fixed real declared index",
            real_index_valid(property_source, got[i]));
      if (real_index_valid(property_source, got[i]))
        values.push_back(real_at(property_source, got[i]));
    end
    check_real_values(label, values, keyed);
  endtask

  function automatic bit text_index_valid(input bit property_source,
                                          input int index);
    return property_source ? (index >= -5 && index <= -2)
                           : (index >= 11 && index <= 14);
  endfunction

  function automatic string text_at(input bit property_source,
                                    input int index);
    return property_source ? holder.texts[index] : direct_texts[index];
  endfunction

  task automatic check_text_indexes(input string label, input int got[$],
                                    input bit property_source,
                                    input bit keyed);
    string values[$];
    int i;
    for (i = 0; i < got.size(); i = i + 1) begin
      check("fixed string declared index",
            text_index_valid(property_source, got[i]));
      if (text_index_valid(property_source, got[i]))
        values.push_back(text_at(property_source, got[i]));
    end
    check_text_values(label, values, keyed);
  endtask

  function automatic bit object_index_valid(input bit property_source,
                                            input int index);
    return property_source ? (index >= 27 && index <= 30)
                           : (index >= 19 && index <= 22);
  endfunction

  function automatic fixed_unique_entry object_at(
      input bit property_source, input int index);
    return property_source ? holder.objects[index] : direct_objects[index];
  endfunction

  task automatic check_object_indexes(input string label, input int got[$],
                                      input bit property_source,
                                      input bit keyed);
    fixed_unique_entry values[$];
    int i;
    for (i = 0; i < got.size(); i = i + 1) begin
      check("fixed object declared index",
            object_index_valid(property_source, got[i]));
      if (object_index_valid(property_source, got[i]))
        values.push_back(object_at(property_source, got[i]));
    end
    check_object_values(label, values, keyed);
  endtask

  task automatic check_declared_index_key(input string label,
                                          input int got[$],
                                          input int low,
                                          input int high,
                                          input int split);
    bit seen_low;
    bit seen_high;
    int i;
    seen_low = 1'b0;
    seen_high = 1'b0;
    check(label, got.size() == 2);
    for (i = 0; i < got.size(); i = i + 1) begin
      check("iterator.index result is a declared index",
            got[i] >= low && got[i] <= high);
      if (got[i] < low || got[i] > high) begin
        // Do not let a bogus out-of-range value satisfy either key class.
      end else if (got[i] < split) begin
        check("one low declared-index key", !seen_low); seen_low = 1'b1;
      end else begin
        check("one high declared-index key", !seen_high); seen_high = 1'b1;
      end
    end
    check(label, seen_low && seen_high);
  endtask

  initial begin
    failed = 1'b0;
    a = new(1, 1);
    b = new(2, 2);
    c = new(3, 1);
    holder = new;
    seq = new;

    direct_bytes[-2] = 10; direct_bytes[-1] = 11;
    direct_bytes[0] = 10; direct_bytes[1] = 12;
    direct_reals[8] = 1.25; direct_reals[7] = 2.5;
    direct_reals[6] = 1.25; direct_reals[5] = 3.75;
    direct_texts[11] = "red"; direct_texts[12] = "blue";
    direct_texts[13] = "red"; direct_texts[14] = "green";
    direct_objects[22] = a; direct_objects[21] = b;
    direct_objects[20] = a; direct_objects[19] = c;

    holder.bytes[3] = 10; holder.bytes[4] = 11;
    holder.bytes[5] = 10; holder.bytes[6] = 12;
    holder.reals[9] = 1.25; holder.reals[8] = 2.5;
    holder.reals[7] = 1.25; holder.reals[6] = 3.75;
    holder.texts[-5] = "red"; holder.texts[-4] = "blue";
    holder.texts[-3] = "red"; holder.texts[-2] = "green";
    holder.objects[30] = a; holder.objects[29] = b;
    holder.objects[28] = a; holder.objects[27] = c;

    seq.mbox_valid_users[0] = 10; seq.mbox_valid_users[1] = 11;
    seq.mbox_valid_users[2] = 10; seq.mbox_valid_users[3] = 12;
    seq.mbox_valid_users[4] = 11; seq.mbox_valid_users[5] = 12;
    seq.build_users();
    check_mailbox_values("fixed mailbox property receiver",
                         seq.mbox_valid_users_uniq);

    // Collateral for the fixed-array marshaler used by this implementation:
    // string storage must survive both directions, including a descending
    // fixed declaration whose range-direction bit shares the descriptor.
    string_dynamic = direct_texts;
    check("fixed string to dynamic round trip outbound",
          string_dynamic.size() == 4 && string_dynamic[0] == "red"
          && string_dynamic[3] == "green");
    indexes = string_dynamic.unique_index;
    text_result.delete();
    for (int copied_index = 0;
         copied_index < indexes.size(); copied_index = copied_index + 1) begin
      check("fixed-derived dynamic array stays zero based",
            indexes[copied_index] >= 0
            && indexes[copied_index] < string_dynamic.size());
      if (indexes[copied_index] >= 0
          && indexes[copied_index] < string_dynamic.size())
        text_result.push_back(string_dynamic[indexes[copied_index]]);
    end
    check_text_values("fixed-derived dynamic unique_index", text_result, 0);
    string_roundtrip = string_dynamic;
    check("dynamic to descending fixed string round trip",
          string_roundtrip[4] == "red" && string_roundtrip[5] == "blue"
          && string_roundtrip[6] == "red"
          && string_roundtrip[7] == "green");
    string_dynamic = string_roundtrip;
    check("descending fixed string back to dynamic",
          string_dynamic.size() == 4 && string_dynamic[0] == "red"
          && string_dynamic[3] == "green");

    byte_result = direct_bytes.unique;
    check_byte_values("direct fixed integral plain unique", byte_result, 0);
    indexes = direct_bytes.unique_index;
    check_byte_indexes("direct fixed integral plain unique_index",
                       indexes, 0, 0);
    byte_result = direct_bytes.unique(item) with (item[0]);
    check_byte_values("direct fixed integral keyed unique", byte_result, 1);
    indexes = direct_bytes.unique_index(item) with (item[0]);
    check_byte_indexes("direct fixed integral keyed unique_index",
                       indexes, 0, 1);

    real_result = direct_reals.unique;
    check_real_values("direct fixed real plain unique", real_result, 0);
    indexes = direct_reals.unique_index;
    check_real_indexes("direct fixed real plain unique_index", indexes, 0, 0);
    real_result = direct_reals.unique(item) with (item >= 2.0);
    check_real_values("direct fixed real keyed unique", real_result, 1);
    indexes = direct_reals.unique_index(item) with (item >= 2.0);
    check_real_indexes("direct fixed real keyed unique_index", indexes, 0, 1);

    text_result = direct_texts.unique;
    check_text_values("direct fixed string plain unique", text_result, 0);
    indexes = direct_texts.unique_index;
    check_text_indexes("direct fixed string plain unique_index", indexes, 0, 0);
    text_result = direct_texts.unique(item) with (item == "red");
    check_text_values("direct fixed string keyed unique", text_result, 1);
    indexes = direct_texts.unique_index(item) with (item == "red");
    check_text_indexes("direct fixed string keyed unique_index", indexes, 0, 1);

    object_result = direct_objects.unique;
    check_object_values("direct fixed class plain unique", object_result, 0);
    indexes = direct_objects.unique_index;
    check_object_indexes("direct fixed class plain unique_index", indexes, 0, 0);
    object_result = direct_objects.unique(item) with (item.group);
    check_object_values("direct fixed class keyed unique", object_result, 1);
    indexes = direct_objects.unique_index(item) with (item.group);
    check_object_indexes("direct fixed class keyed unique_index", indexes, 0, 1);

    byte_result = holder.bytes.unique;
    check_byte_values("property fixed integral plain unique", byte_result, 0);
    indexes = holder.bytes.unique_index;
    check_byte_indexes("property fixed integral plain unique_index",
                       indexes, 1, 0);
    byte_result = holder.bytes.unique(item) with (item[0]);
    check_byte_values("property fixed integral keyed unique", byte_result, 1);
    indexes = holder.bytes.unique_index(item) with (item[0]);
    check_byte_indexes("property fixed integral keyed unique_index",
                       indexes, 1, 1);

    real_result = holder.reals.unique;
    check_real_values("property fixed real plain unique", real_result, 0);
    indexes = holder.reals.unique_index;
    check_real_indexes("property fixed real plain unique_index", indexes, 1, 0);
    real_result = holder.reals.unique(item) with (item >= 2.0);
    check_real_values("property fixed real keyed unique", real_result, 1);
    indexes = holder.reals.unique_index(item) with (item >= 2.0);
    check_real_indexes("property fixed real keyed unique_index", indexes, 1, 1);

    text_result = holder.texts.unique;
    check_text_values("property fixed string plain unique", text_result, 0);
    indexes = holder.texts.unique_index;
    check_text_indexes("property fixed string plain unique_index", indexes, 1, 0);
    text_result = holder.texts.unique(item) with (item == "red");
    check_text_values("property fixed string keyed unique", text_result, 1);
    indexes = holder.texts.unique_index(item) with (item == "red");
    check_text_indexes("property fixed string keyed unique_index", indexes, 1, 1);

    object_result = holder.objects.unique;
    check_object_values("property fixed class plain unique", object_result, 0);
    indexes = holder.objects.unique_index;
    check_object_indexes("property fixed class plain unique_index", indexes, 1, 0);
    object_result = holder.objects.unique(item) with (item.group);
    check_object_values("property fixed class keyed unique", object_result, 1);
    indexes = holder.objects.unique_index(item) with (item.group);
    check_object_indexes("property fixed class keyed unique_index", indexes, 1, 1);

    byte_result = direct_bytes.unique(item) with (item.index < 0);
    check("direct fixed iterator.index uses declared negative indexes",
          byte_result.size() == 2);
    indexes = direct_bytes.unique_index(item) with (item.index < 0);
    check_declared_index_key("direct fixed unique_index/iterator.index",
                             indexes, -2, 1, 0);
    byte_result = holder.bytes.unique(item) with (item.index < 5);
    check("property fixed iterator.index uses declared nonzero indexes",
          byte_result.size() == 2);
    indexes = holder.bytes.unique_index(item) with (item.index < 5);
    check_declared_index_key("property fixed unique_index/iterator.index",
                             indexes, 3, 6, 5);

    if (failed)
      $fatal(1, "fixed-array unique checks failed");
    $display("PASSED");
  end
endmodule
