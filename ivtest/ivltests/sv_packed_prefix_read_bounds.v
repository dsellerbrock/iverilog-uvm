module sv_packed_prefix_read_bounds;
  logic [1:0][2:0][7:0] words;
  logic [2:1][4:2][9:2] nonzero;
  logic [1:2][2:4][2:9] ascending;
  logic [1:0][2:0][7:0] memory [0:0];
  bit [1:0][2:0][7:0] two_state_words;
  logic [3:0] value;
  logic [1:0] outer_index;
  logic [2:0] middle_index;
  logic [127:0] wide_prefix;
  integer prefix_calls;
  integer final_calls;

  function automatic integer counted_prefix(input integer value_in);
    prefix_calls += 1;
    return value_in;
  endfunction

  function automatic integer counted_final;
    final_calls += 1;
    return 0;
  endfunction

  task automatic check_value(input logic condition, input string label);
    if (condition !== 1'b1)
      $fatal(1, "FAILED: %s", label);
  endtask

  initial begin
    words = 48'h112233aabbcc;
    memory[0] = words;
    two_state_words = 48'h112233aabbcc;
    nonzero = '0;
    nonzero[2][4] = 8'ha5;
    ascending = '0;
    ascending[1][2] = 8'h3c;

    value = words[0][3][0 +: 4];
    check_value(value === 4'bxxxx, "middle prefix above range");
    value = words[1][-1][3 -: 4];
    check_value(value === 4'bxxxx, "middle prefix below range");
    value = words[2][1][0 +: 4];
    check_value(value === 4'bxxxx, "outer prefix above range");
    value = words[-1][1][3 -: 4];
    check_value(value === 4'bxxxx, "outer prefix below range");
    value = words[0][2'bx][0 +: 4];
    check_value(value === 4'bxxxx, "middle X prefix");
    value = words[2'bz][1][3 -: 4];
    check_value(value === 4'bxxxx, "outer Z prefix");
    value = two_state_words[0][3][0 +: 4];
    check_value(value === 4'b0000, "two-state invalid prefix");

    outer_index = 0;
    middle_index = 1;
    value = words[outer_index][middle_index][0 +: 4];
    check_value(value === 4'hb, "dynamic valid prefixes");
    middle_index = 3;
    value = words[outer_index][middle_index][0 +: 4];
    check_value(value === 4'bxxxx, "dynamic out-of-range middle prefix");
    middle_index = 3'bxxx;
    value = words[outer_index][middle_index][0 +: 4];
    check_value(value === 4'bxxxx, "dynamic X middle prefix");
    wide_prefix = 128'd1 << 100;
    value = words[0][wide_prefix][0 +: 4];
    check_value(value === 4'bxxxx, "wide dynamic middle prefix");
    value = words[64'h1_0000_0000][1][0 +: 4];
    check_value(value === 4'bxxxx, "wide constant outer prefix");
    value = words[0][128'hffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff]
                 [0 +: 4];
    check_value(value === 4'bxxxx, "maximum unsigned middle prefix");

    value = nonzero[2][4][5 +: 4];
    check_value(value === 4'h4, "descending nonzero valid boundary");
    value = nonzero[2][5][5 +: 4];
    check_value(value === 4'bxxxx, "descending nonzero invalid prefix");
    value = ascending[1][2][5 +: 4];
    check_value(value === 4'he, "ascending nonzero valid boundary");
    value = ascending[1][1][5 +: 4];
    check_value(value === 4'bxxxx, "ascending nonzero invalid prefix");

    prefix_calls = 0;
    final_calls = 0;
    value = words[0][counted_prefix(3)][counted_final() +: 4];
    check_value(prefix_calls == 1, "invalid prefix evaluated once");
    check_value(final_calls == 1, "final index evaluated once after invalid prefix");
    check_value(value === 4'bxxxx, "counted invalid prefix result");

    value = memory[0][0][3][0 +: 4];
    check_value(value === 4'bxxxx, "unpacked word invalid packed prefix");
    middle_index = 3;
    value = memory[0][0][middle_index][0 +: 4];
    check_value(value === 4'bxxxx,
                "unpacked word dynamic invalid packed prefix");
    middle_index = 1;
    value = memory[0][0][middle_index][0 +: 4];
    check_value(value === 4'hb,
                "unpacked word dynamic valid packed prefix");

    check_value(words[0][1][0 +: 4] === 4'hb,
                "valid interior element unchanged");
    check_value(words[1][0 +: 2] === 16'h2233,
                "short subarray selection unchanged");
    $display("PASSED");
  end
endmodule
