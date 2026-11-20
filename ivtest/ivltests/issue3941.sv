// IEEE 1800-2017/2023 4.9.1, 10.3.2-10.3.4, 11.3.5, 11.4.7, 11.4.11.
module issue3941;
  logic [1:0] selected = 0;
  logic [7:0] sibling = 0;
  int calls = 0;
  function automatic logic [7:0] f(input bit arg);
    calls++;
    return arg ? 11 : 0;
  endfunction
  wire [7:0] result = f(selected[0]) + sibling;

  task automatic check_result(input logic [7:0] value, input int count);
    $display("%0d/%0d", result, calls);
    if (result !== value || calls != count)
      $fatal(1, "expected %0d/%0d", value, count);
  endtask

  int a = 2, b = 3;
  int inner_calls = 0, outer_calls = 0;
  function automatic int inner(input int arg);
    inner_calls++;
    return 1 << arg;
  endfunction
  function automatic int outer(input int arg);
    outer_calls++;
    return arg;
  endfunction
  wire [7:0] computed = $clog2(outer(inner(a + b)));

  int zero_calls = 0, constant_calls = 0;
  function automatic int no_arguments();
    return ++zero_calls;
  endfunction
  function automatic int constant_inputs();
    constant_calls++;
    return 9;
  endfunction
  wire [7:0] zero = no_arguments() + sibling;
  wire [7:0] constant_result = constant_inputs();

  logic [5:2] words [2:3] = '{4'b0100, 4'b0100};
  int index = 2, base = 3;
  int dynamic_calls = 0, static_calls = 0, word_calls = 0;
  function automatic logic [1:0] part_value(input logic [1:0] val);
    dynamic_calls++;
    return val;
  endfunction
  function automatic logic [1:0] static_part_value(input logic [1:0] val);
    static_calls++;
    return val;
  endfunction
  function automatic logic [3:0] word_value(input logic [3:0] val);
    word_calls++;
    return val;
  endfunction
  wire [1:0] dynamic_part = part_value(words[index][base +: 2]);
  wire [1:0] static_part = static_part_value(words[2][4:3]);
  wire [3:0] dynamic_word = word_value(words[index]);

  int index_calls = 0;
  function automatic int select_word(input int word_index);
    index_calls++;
    return word_index;
  endfunction
  wire [1:0] call_index_part = words[select_word(index)][4:3];

  logic enable = 0, gate_arg = 0;
  int gate_calls = 0;
  function automatic logic gated(input logic arg);
    gate_calls++;
    return arg;
  endfunction
  wire gated_result = enable && gated(gate_arg);

  logic choose = 0;
  int true_calls = 0, false_calls = 0;
  function automatic logic [3:0] on_true();
    true_calls++;
    return 4'b1010;
  endfunction
  function automatic logic [3:0] on_false();
    false_calls++;
    return 4'b1001;
  endfunction
  wire [3:0] conditional = choose ? on_true() : on_false();

  real real_sibling = 0.25;
  int real_calls = 0;
  function automatic real real_call(input real arg);
    real_calls++;
    return 2.0 * arg;
  endfunction
  wire real real_result = real_call(1.5) + real_sibling;

  function automatic real fractional();
    return -2.75;
  endfunction
  function automatic logic [3:0] unknown_bits();
    return 4'b1xz1;
  endfunction
  logic signed [7:0] rounded;
  bit [3:0] converted;
  assign rounded = fractional();
  assign converted = unknown_bits();

  logic [1:0] pulse = 0;
  int delay_calls = 0;
  function automatic logic [1:0] delayed_call();
    delay_calls++;
    return 2'b00;
  endfunction
  wire [1:0] delayed;
  assign #5 delayed = delayed_call() | pulse;
  always @(delayed)
    if ($time > 5 && delayed !== 2'b00)
      $fatal(1, "short vector pulse reached the destination");

  logic pull_low = 0;
  logic drive_bit = 0;
  function automatic logic strength_call(input logic arg);
    return arg;
  endfunction
  wire resolved;
  assign (weak0, weak1) resolved = strength_call(drive_bit);
  assign (pull0, pull1) resolved = pull_low ? 1'b0 : 1'b1;

  initial begin
    #1;
    check_result(0, 1);
    if (computed !== 5 || inner_calls != 1 || outer_calls != 1 ||
        zero !== 1 || zero_calls != 1 || constant_result !== 9 ||
        constant_calls != 1 || dynamic_part !== 2'b10 || dynamic_calls != 1 ||
        static_part !== 2'b10 || static_calls != 1 ||
        dynamic_word !== 4'b0100 || word_calls != 1 ||
        call_index_part !== 2'b10 || index_calls != 1)
      $fatal(1, "wrong initial operands or call count");
    if (gated_result !== 0 || gate_calls != 0 || conditional !== 4'b1001 ||
        true_calls != 0 || false_calls != 1 || real_result != 3.25 ||
        real_calls != 1 || resolved !== 1'b1)
      $fatal(1, "wrong initial short-circuit, real, or strength result");
    if (rounded !== -8'sd3 || converted !== 4'b1001)
      $fatal(1, "wrong assignment conversion");

    selected[1] = 1;
    a = 3;
    b = 2; // Both operands change, with the same computed argument value.
    words[2][2] = 1; // Outside the selected packed range.
    words[3][5] = 1; // Outside the selected word.
    gate_arg = 1;
    choose = 1;
    real_sibling = 1.75;
    drive_bit = 1;
    pull_low = 1;
    #1;
    check_result(0, 1);
    if (computed !== 5 || inner_calls != 2 || outer_calls != 2 ||
        dynamic_part !== 2'b10 || dynamic_calls != 1 ||
        static_part !== 2'b10 || static_calls != 1 ||
        dynamic_word !== 4'b0101 || word_calls != 2 || index_calls != 1)
      $fatal(1, "wrong computed argument or selected range sensitivity");
    if (gated_result !== 0 || gate_calls != 0 || conditional !== 4'b1010 ||
        true_calls != 1 || false_calls != 1 || real_result != 4.75 ||
        real_calls != 2 || resolved !== 1'b0)
      $fatal(1, "wrong short-circuit, real, or strength update");

    sibling = 15;
    b = 3;
    index = 3; // The newly selected word has the same selected part.
    enable = 1;
    choose = 1'bx;
    #1;
    check_result(15, 2);
    if (computed !== 6 || inner_calls != 3 || outer_calls != 3 ||
        zero !== 17 || zero_calls != 2 || constant_calls != 1 ||
        dynamic_part !== 2'b10 || dynamic_calls != 1 ||
        static_calls != 1 || dynamic_word !== 4'b1100 || word_calls != 3 ||
        call_index_part !== 2'b10 || index_calls != 2)
      $fatal(1, "wrong nested argument, zero-argument, or word update");
    if (gated_result !== 1 || gate_calls != 1 || conditional !== 4'b10xx ||
        true_calls != 2 || false_calls != 2)
      $fatal(1, "wrong logical or unknown-conditional evaluation");

    sibling = 16;
    base = 4;
    #1;
    check_result(16, 3);
    if (dynamic_part !== 2'b11 || dynamic_calls != 2 ||
        static_calls != 1 || word_calls != 3)
      $fatal(1, "wrong indexed part-select update");

    selected[0] = 1;
    words[2][3] = 1;
    #1;
    check_result(27, 4);
    if (dynamic_calls != 2 || static_part !== 2'b11 || static_calls != 2 ||
        word_calls != 3 || index_calls != 2)
      $fatal(1, "wrong static word/part-select update");

    sibling = 27;
    words[3][3] = 1;
    #1;
    check_result(38, 5);
    if (call_index_part !== 2'b11 || index_calls != 3)
      $fatal(1, "call-bearing select did not observe the selected data");
    if (delayed !== 2'b00 || delay_calls != 1)
      $fatal(1, "wrong initial delayed value or evaluation count");
    pulse = 2'b11;
    #2;
    if (delayed !== 2'b00 || delay_calls != 2)
      $fatal(1, "rising operand did not evaluate before the delay");
    pulse = 2'b00;
    #6;
    if (delayed !== 2'b00 || delay_calls != 3)
      $fatal(1, "falling operand did not evaluate or pulse was not rejected");
    $display("PASSED");
  end
endmodule
