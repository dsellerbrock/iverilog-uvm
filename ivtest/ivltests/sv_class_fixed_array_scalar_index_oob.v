// Invalid indices on fixed unpacked scalar-valued class properties must never
// alias canonical slot zero. Exercise every VVP value stack plus packed RMW.

typedef struct {
  int count;
  string name;
} fixed_scalar_record_t;

class fixed_scalar_leaf;
  int value;

  function new(int value = 0);
    this.value = value;
  endfunction
endclass

class fixed_scalar_holder;
  logic [15:0] words[0:1][0:1];
  bit flags[0:1][0:1];
  real reals[0:1][0:1];
  string strings[0:1][0:1];
  fixed_scalar_leaf handles[0:1][0:1];
  fixed_scalar_record_t records[0:1][0:1];
endclass

module sv_class_fixed_array_scalar_index_oob;
  bit failed;
  int first_index_calls;
  int second_index_calls;
  int wide_index_calls;
  int rhs_calls;
  logic signed [31:0] first_index_value;
  logic signed [31:0] second_index_value;
  logic [95:0] wide_index_value;
  fixed_scalar_leaf rhs_handle_value;
  fixed_scalar_record_t rhs_record_value;

  function automatic logic signed [31:0] next_first_index();
    first_index_calls++;
    return first_index_value;
  endfunction

  function automatic logic signed [31:0] next_second_index();
    second_index_calls++;
    return second_index_value;
  endfunction

  function automatic logic [95:0] next_wide_index();
    wide_index_calls++;
    return wide_index_value;
  endfunction

  function automatic logic [15:0] next_word();
    rhs_calls++;
    return 16'hdead;
  endfunction

  function automatic logic [3:0] next_nibble();
    rhs_calls++;
    return 4'hf;
  endfunction

  function automatic bit next_flag();
    rhs_calls++;
    return 1'b0;
  endfunction

  function automatic real next_real();
    rhs_calls++;
    return 9.5;
  endfunction

  function automatic string next_string();
    rhs_calls++;
    return "bad";
  endfunction

  function automatic fixed_scalar_leaf next_handle();
    rhs_calls++;
    return rhs_handle_value;
  endfunction

  function automatic fixed_scalar_record_t next_record();
    rhs_calls++;
    return rhs_record_value;
  endfunction

  task automatic arm_indices(
      input logic signed [31:0] first_value,
      input logic signed [31:0] second_value);
    first_index_value = first_value;
    second_index_value = second_value;
    first_index_calls = 0;
    second_index_calls = 0;
    wide_index_calls = 0;
    rhs_calls = 0;
  endtask

  task automatic check(input string label, input bit ok);
    if (!ok) begin
      $display("FAILED -- %0s", label);
      failed = 1'b1;
    end
  endtask

  initial begin
    automatic fixed_scalar_holder holder = new;
    automatic fixed_scalar_leaf live_handle = new(41);
    automatic fixed_scalar_leaf replacement_handle = new(99);
    automatic fixed_scalar_leaf got_handle;
    automatic fixed_scalar_record_t live_record;
    automatic fixed_scalar_record_t got_record;
    automatic logic [15:0] got_word;
    automatic bit got_flag;
    automatic real got_real;
    automatic string got_string;

    rhs_handle_value = replacement_handle;
    rhs_record_value.count = 99;
    rhs_record_value.name = "bad";
    live_record.count = 55;
    live_record.name = "live-record";

    holder.words[0][0] = 16'h1234;
    holder.flags[0][0] = 1'b1;
    holder.reals[0][0] = 3.25;
    holder.strings[0][0] = "live-string";
    holder.handles[0][0] = live_handle;
    holder.records[0][0] = live_record;

    // [-1][2] would flatten to canonical slot zero if dimensions were not
    // checked independently. Reads must return type defaults, exactly once.
    arm_indices(-1, 2);
    got_word = holder.words[next_first_index()][next_second_index()];
    check("cancelling invalid vec read",
          $isunknown(got_word) &&
          first_index_calls == 1 && second_index_calls == 1);

    arm_indices(-1, 2);
    got_flag = holder.flags[next_first_index()][next_second_index()];
    check("cancelling invalid bit read",
          got_flag == 1'b0 &&
          first_index_calls == 1 && second_index_calls == 1);

    arm_indices(-1, 2);
    got_real = holder.reals[next_first_index()][next_second_index()];
    check("cancelling invalid real read",
          got_real == 0.0 &&
          first_index_calls == 1 && second_index_calls == 1);

    arm_indices(-1, 2);
    got_string = holder.strings[next_first_index()][next_second_index()];
    check("cancelling invalid string read",
          got_string == "" &&
          first_index_calls == 1 && second_index_calls == 1);

    arm_indices(-1, 2);
    got_handle = holder.handles[next_first_index()][next_second_index()];
    check("cancelling invalid class-handle read",
          got_handle == null &&
          first_index_calls == 1 && second_index_calls == 1);

    arm_indices(-1, 2);
    got_record = holder.records[next_first_index()][next_second_index()];
    check("cancelling invalid unpacked-struct read",
          got_record.count !== 55 && got_record.name == "" &&
          first_index_calls == 1 && second_index_calls == 1);

    // Invalid whole-element writes still evaluate every index and RHS once,
    // but must not alter the live value in canonical slot zero.
    arm_indices(-1, 2);
    holder.words[next_first_index()][next_second_index()] = next_word();
    check("cancelling invalid vec write evaluated once",
          holder.words[0][0] == 16'h1234 && rhs_calls == 1 &&
          first_index_calls == 1 && second_index_calls == 1);

    arm_indices(-1, 2);
    holder.flags[next_first_index()][next_second_index()] = next_flag();
    check("cancelling invalid bit write evaluated once",
          holder.flags[0][0] == 1'b1 && rhs_calls == 1 &&
          first_index_calls == 1 && second_index_calls == 1);

    arm_indices(-1, 2);
    holder.reals[next_first_index()][next_second_index()] = next_real();
    check("cancelling invalid real write evaluated once",
          holder.reals[0][0] == 3.25 && rhs_calls == 1 &&
          first_index_calls == 1 && second_index_calls == 1);

    arm_indices(-1, 2);
    holder.strings[next_first_index()][next_second_index()] = next_string();
    check("cancelling invalid string write evaluated once",
          holder.strings[0][0] == "live-string" && rhs_calls == 1 &&
          first_index_calls == 1 && second_index_calls == 1);

    arm_indices(-1, 2);
    holder.handles[next_first_index()][next_second_index()] = next_handle();
    check("cancelling invalid class-handle write evaluated once",
          holder.handles[0][0] == live_handle && rhs_calls == 1 &&
          first_index_calls == 1 && second_index_calls == 1);

    arm_indices(-1, 2);
    holder.records[next_first_index()][next_second_index()] = next_record();
    check("cancelling invalid unpacked-struct write evaluated once",
          holder.records[0][0].count == 55 &&
          holder.records[0][0].name == "live-record" && rhs_calls == 1 &&
          first_index_calls == 1 && second_index_calls == 1);

    // A packed part update is read-modify-write on the selected scalar leaf.
    // It needs the same invalid-slot guard on both the read and store halves.
    arm_indices(-1, 2);
    holder.words[next_first_index()][next_second_index()][7:4] =
        next_nibble();
    check("cancelling invalid packed RMW evaluated once",
          holder.words[0][0] == 16'h1234 && rhs_calls == 1 &&
          first_index_calls == 1 && second_index_calls == 1);

    arm_indices('x, 0);
    got_word = holder.words[next_first_index()][next_second_index()];
    check("X fixed dimension read",
          $isunknown(got_word) &&
          first_index_calls == 1 && second_index_calls == 1);

    arm_indices(0, 'x);
    holder.words[next_first_index()][next_second_index()][3:0] =
        next_nibble();
    check("X fixed dimension packed RMW",
          holder.words[0][0] == 16'h1234 && rhs_calls == 1 &&
          first_index_calls == 1 && second_index_calls == 1);

    arm_indices('z, 1);
    got_string = holder.strings[next_first_index()][next_second_index()];
    check("Z fixed dimension string read",
          got_string == "" &&
          first_index_calls == 1 && second_index_calls == 1);

    arm_indices(1, 'z);
    holder.reals[next_first_index()][next_second_index()] = next_real();
    check("Z fixed dimension real write",
          holder.reals[0][0] == 3.25 && rhs_calls == 1 &&
          first_index_calls == 1 && second_index_calls == 1);

    // Preserve the full raw unsigned index: a high bit above 64 must not be
    // truncated to zero before the range check.
    arm_indices(0, 0);
    wide_index_value = {1'b1, 95'b0};
    got_word = holder.words[next_wide_index()][next_second_index()];
    check("wide unsigned OOB read",
          $isunknown(got_word) && wide_index_calls == 1 &&
          second_index_calls == 1);

    arm_indices(0, 0);
    holder.words[next_wide_index()][next_second_index()][11:8] =
        next_nibble();
    check("wide unsigned OOB packed RMW",
          holder.words[0][0] == 16'h1234 && rhs_calls == 1 &&
          wide_index_calls == 1 && second_index_calls == 1);

    // Direct constant invalid forms take the same sentinel path.
    holder.words[-1][2] = next_word();
    holder.handles[-1][2] = next_handle();
    check("constant cancelling invalid writes",
          holder.words[0][0] == 16'h1234 &&
          holder.handles[0][0] == live_handle && rhs_calls == 3);

    // Valid accesses after every invalid stack kind catch leaked vec, real,
    // string, or object-stack values.
    holder.words[1][1] = 16'ha55a;
    holder.flags[1][1] = 1'b1;
    holder.reals[1][1] = 7.75;
    holder.strings[1][1] = "after";
    holder.handles[1][1] = replacement_handle;
    holder.records[1][1] = rhs_record_value;
    check("valid scalar operations after invalids",
          holder.words[1][1] == 16'ha55a && holder.flags[1][1] &&
          holder.reals[1][1] == 7.75 &&
          holder.strings[1][1] == "after" &&
          holder.handles[1][1] == replacement_handle &&
          holder.records[1][1].count == 99);

    check("canonical slot zero remains intact",
          holder.words[0][0] == 16'h1234 && holder.flags[0][0] &&
          holder.reals[0][0] == 3.25 &&
          holder.strings[0][0] == "live-string" &&
          holder.handles[0][0] == live_handle && live_handle.value == 41 &&
          holder.records[0][0].count == 55 &&
          holder.records[0][0].name == "live-record");

    if (failed)
      $fatal(1, "fixed scalar property invalid-index checks failed");
    $display("PASSED");
  end
endmodule
