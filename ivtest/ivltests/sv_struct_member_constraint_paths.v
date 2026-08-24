// IEEE 1800-2017 18.5 and 18.7.1: an unqualified inline name resolves in
// the randomized object before same-named caller state. Explicit this/super
// paths retain the exact inherited outer/member identity. Unary and adjacent
// mixed-width binary folding must preserve signed 64-bit values through model
// write-back.
typedef struct {
  rand bit [7:0] value;
  rand logic signed [63:0] signed_value;
  rand logic signed [63:0] signed_binary;
} constraint_path_record_t;

class inline_path_item;
  rand constraint_path_record_t record;
  rand bit [7:0] value;
endclass

class base_path_item;
  rand constraint_path_record_t base_record;
endclass

class derived_path_item extends base_path_item;
  rand constraint_path_record_t record;
  // These same-named scalar properties catch terminal-name fallback.
  rand bit [7:0] value;
  rand logic signed [63:0] signed_value;
  rand logic signed [63:0] signed_binary;

  constraint explicit_paths {
    this.record.value == 8'd44;
    super.base_record.value == 8'd33;
    this.record.signed_value == -64'sd7;
    this.record.signed_binary == (8'shff + -64'sd6);
  }
endclass

class indexed_path_item;
  rand constraint_path_record_t record;
  bit [7:0] expected;
  bit signed [63:0] signed_expected;

  constraint match_expected {
    record.value == expected;
    record.signed_value == signed_expected;
  }
endclass

module test;
  indexed_path_item items[2];
  indexed_path_item dynamic_items[];
  integer receiver_index_calls;
  integer dynamic_index_calls;
  integer dynamic_mode_calls;
  integer dynamic_eval_sequence;
  integer dynamic_index_order;
  integer dynamic_mode_order;
  integer dynamic_selected_index;

  function automatic integer next_receiver_index;
    receiver_index_calls += 1;
    return 0;
  endfunction

  function automatic integer next_dynamic_index;
    dynamic_index_calls += 1;
    dynamic_eval_sequence += 1;
    dynamic_index_order = dynamic_eval_sequence;
    return dynamic_selected_index;
  endfunction

  function automatic integer next_dynamic_mode;
    dynamic_mode_calls += 1;
    dynamic_eval_sequence += 1;
    dynamic_mode_order = dynamic_eval_sequence;
    return 0;
  endfunction

  initial begin
    constraint_path_record_t record;
    inline_path_item item;
    derived_path_item inherited;
    integer bad_index;

    item = new;
    record.value = 8'd99;
    if (item.randomize() with {
          record.value == 8'd21;
          local::record.value == 8'd99;
        } !== 1)
      $fatal(1, "unqualified inline target-member solve failed");
    if (item.record.value !== 8'd21 || record.value !== 8'd99)
      $fatal(1, "same-named caller state captured the inline target member");

    if (item.randomize() with (record) {
          record.value == 8'd22;
          local::record.value == 8'd99;
        } !== 1)
      $fatal(1, "with(identifier_list) target-member solve failed");
    if (item.record.value !== 8'd22 || record.value !== 8'd99)
      $fatal(1, "with(identifier_list) lost target-member precedence");

    inherited = new;
    if (inherited.randomize() !== 1)
      $fatal(1, "this/super struct-member solve failed");
    if (inherited.record.value !== 8'd44)
      $fatal(1, "this.record.value lost its member identity");
    if (inherited.base_record.value !== 8'd33)
      $fatal(1, "super.base_record.value lost its inherited identity");
    if (inherited.record.signed_value !== -64'sd7
        || inherited.record.signed_value !== 64'hffff_ffff_ffff_fff9)
      $fatal(1, "signed 64-bit unary constant was not written back exactly");
    if (inherited.record.signed_binary !== -64'sd7
        || inherited.record.signed_binary !== 64'hffff_ffff_ffff_fff9)
      $fatal(1, "mixed-width signed binary folding lost sign extension");

    // The fixed-array index is part of the class receiver, not part of the
    // unpacked-struct constraint path.  Setter and query must select the same
    // object exactly once and leave the adjacent object independent.
    items[0] = new;
    items[1] = new;
    items[0].record.value = 8'd9;
    items[0].expected = 8'd19;
    items[1].record.value = 8'd8;
    items[1].expected = 8'd29;
    receiver_index_calls = 0;

    if (items[0].record.value.rand_mode() !== 1
        || items[1].record.value.rand_mode() !== 1)
      $fatal(1, "indexed struct-member modes did not start enabled");
    items[next_receiver_index()].record.value.rand_mode(0);
    if (receiver_index_calls !== 1)
      $fatal(1, "indexed struct-member setter evaluated its receiver %0d times",
             receiver_index_calls);
    if (items[next_receiver_index()].record.value.rand_mode() !== 0
        || receiver_index_calls !== 2)
      $fatal(1, "indexed struct-member query lost its receiver or evaluation count");
    if (items[1].record.value.rand_mode() !== 1)
      $fatal(1, "items[0] rand_mode leaked into items[1]");

    // A frozen value contradicting the class constraint makes randomize fail
    // atomically.  The adjacent active object still solves and writes back.
    if (items[0].randomize() !== 0 || items[0].record.value !== 8'd9)
      $fatal(1, "indexed receiver did not freeze the contradictory member");
    if (items[1].randomize() !== 1 || items[1].record.value !== 8'd29)
      $fatal(1, "indexed receiver corrupted the adjacent active object");

    items[0].record.value.rand_mode(1);
    if (items[0].record.value.rand_mode() !== 1
        || items[0].randomize() !== 1
        || items[0].record.value !== 8'd19)
      $fatal(1, "indexed struct-member mode did not re-enable");

    // Match existing fixed-array rand_mode semantics: an out-of-range
    // receiver is a setter no-op and a disabled query, and cannot alter a
    // valid element's mode.
    bad_index = 2;
    items[bad_index].record.value.rand_mode(0);
    if (items[bad_index].record.value.rand_mode() !== 0
        || items[0].record.value.rand_mode() !== 1
        || items[1].record.value.rand_mode() !== 1)
      $fatal(1, "out-of-range indexed receiver corrupted valid member mode");

    items[1] = null;
    items[1].record.value.rand_mode(0);
    if (items[1].record.value.rand_mode() !== 0
        || items[0].record.value.rand_mode() !== 1)
      $fatal(1, "null indexed receiver corrupted valid member mode");

    // A dynamic-array element has the same class-receiver semantics.  The
    // index and setter argument each evaluate once. Their relative order is
    // deliberately not pinned because expression evaluation order is not an
    // IEEE guarantee.
    dynamic_items = new[2];
    dynamic_items[0] = new;
    dynamic_items[1] = new;
    dynamic_items[0].record.value = 8'd39;
    dynamic_items[0].expected = 8'd49;
    dynamic_items[0].record.signed_value = 64'sd109;
    dynamic_items[0].signed_expected = 64'sd209;
    dynamic_items[1].record.value = 8'd38;
    dynamic_items[1].expected = 8'd59;
    dynamic_items[1].record.signed_value = 64'sd119;
    dynamic_items[1].signed_expected = 64'sd219;

    if (dynamic_items[0].record.value.rand_mode() !== 1
        || dynamic_items[1].record.value.rand_mode() !== 1)
      $fatal(1, "dynamic indexed struct-member modes did not start enabled");
    dynamic_index_calls = 0;
    dynamic_mode_calls = 0;
    dynamic_eval_sequence = 0;
    dynamic_index_order = 0;
    dynamic_mode_order = 0;
    dynamic_selected_index = 0;
    dynamic_items[next_dynamic_index()].record.value.rand_mode(
          next_dynamic_mode());
    if (dynamic_index_calls !== 1 || dynamic_mode_calls !== 1
        || dynamic_eval_sequence !== 2
        || dynamic_index_order == dynamic_mode_order
        || dynamic_index_order + dynamic_mode_order !== 3)
      $fatal(1, "dynamic setter did not evaluate index/mode exactly once");
    if (dynamic_items[next_dynamic_index()].record.value.rand_mode() !== 0
        || dynamic_index_calls !== 2 || dynamic_mode_calls !== 1)
      $fatal(1, "dynamic query lost its receiver or evaluation count");
    if (dynamic_items[1].record.value.rand_mode() !== 1
        || dynamic_items[0].record.signed_value.rand_mode() !== 1)
      $fatal(1, "dynamic member mode leaked into an object or sibling leaf");

    // The disabled contradictory leaf makes the solve fail. The other active
    // struct member may participate in solving but cannot be written back.
    if (dynamic_items[0].randomize() !== 0
        || dynamic_items[0].record.value !== 8'd39
        || dynamic_items[0].record.signed_value !== 64'sd109
        || dynamic_items[0].record.signed_value.rand_mode() !== 1)
      $fatal(1, "dynamic indexed failure did not roll back active sibling");
    if (dynamic_items[1].randomize() !== 1
        || dynamic_items[1].record.value !== 8'd59
        || dynamic_items[1].record.signed_value !== 64'sd219)
      $fatal(1, "dynamic indexed receiver corrupted adjacent active object");

    dynamic_items[0].record.value.rand_mode(1);
    if (dynamic_items[0].record.value.rand_mode() !== 1
        || dynamic_items[0].randomize() !== 1
        || dynamic_items[0].record.value !== 8'd49
        || dynamic_items[0].record.signed_value !== 64'sd209)
      $fatal(1, "dynamic indexed struct-member mode did not re-enable");

    // Established Icarus semantics keep an out-of-range receiver as a
    // setter no-op and disabled query. Receiver and argument side effects
    // still occur exactly once.
    bad_index = 2;
    dynamic_index_calls = 0;
    dynamic_mode_calls = 0;
    dynamic_eval_sequence = 0;
    dynamic_index_order = 0;
    dynamic_mode_order = 0;
    dynamic_selected_index = bad_index;
    dynamic_items[next_dynamic_index()].record.value.rand_mode(
          next_dynamic_mode());
    if (dynamic_index_calls !== 1 || dynamic_mode_calls !== 1
        || dynamic_eval_sequence !== 2
        || dynamic_index_order == dynamic_mode_order
        || dynamic_index_order + dynamic_mode_order !== 3)
      $fatal(1, "dynamic OOB setter lost index/mode side effects");
    if (dynamic_items[next_dynamic_index()].record.value.rand_mode() !== 0
        || dynamic_index_calls !== 2 || dynamic_mode_calls !== 1
        || dynamic_items[0].record.value.rand_mode() !== 1
        || dynamic_items[1].record.value.rand_mode() !== 1)
      $fatal(1, "dynamic out-of-range receiver corrupted valid member mode");

    // A null selected element follows the same established no-op/query-zero
    // behavior and cannot suppress or repeat receiver/argument side effects.
    dynamic_items[1] = null;
    dynamic_index_calls = 0;
    dynamic_mode_calls = 0;
    dynamic_eval_sequence = 0;
    dynamic_index_order = 0;
    dynamic_mode_order = 0;
    dynamic_selected_index = 1;
    dynamic_items[next_dynamic_index()].record.value.rand_mode(
          next_dynamic_mode());
    if (dynamic_index_calls !== 1 || dynamic_mode_calls !== 1
        || dynamic_eval_sequence !== 2
        || dynamic_index_order == dynamic_mode_order
        || dynamic_index_order + dynamic_mode_order !== 3)
      $fatal(1, "dynamic null setter lost index/mode side effects");
    if (dynamic_items[next_dynamic_index()].record.value.rand_mode() !== 0
        || dynamic_index_calls !== 2 || dynamic_mode_calls !== 1
        || dynamic_items[0].record.value.rand_mode() !== 1)
      $fatal(1, "dynamic null receiver corrupted valid member mode");

    $display("PASSED");
  end
endmodule
