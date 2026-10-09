module sv_packed_multidim_dynamic_select_bounds;
  logic [1:0][2:0][7:0] words;
  logic [1:0] outer_index;
  logic [2:0] middle_index;
  logic [3:0] inner_index;
  logic bit_value;
  integer inner_index_calls;

  function automatic integer counted_inner_index;
    inner_index_calls += 1;
    return 8;
  endfunction

  task automatic check_value(input logic condition, input string label);
    if (condition !== 1'b1)
      $fatal(1, "FAILED: %s", label);
  endtask

  initial begin
    words = 48'h112233aabbcc;
    outer_index = 0;
    middle_index = 0;
    inner_index = 7;
    bit_value = words[outer_index][middle_index][inner_index];
    check_value(bit_value === 1'b1, "valid boundary index");

    inner_index = 8;
    bit_value = words[outer_index][middle_index][inner_index];
    check_value(bit_value === 1'bx, "inner dimension out of bounds");

    bit_value = words[0][0][inner_index];
    check_value(bit_value === 1'bx,
                "runtime final index after a constant prefix");

    outer_index = 0;
    middle_index = 0;
    inner_index_calls = 0;
    bit_value = words[outer_index][middle_index][counted_inner_index()];
    check_value(inner_index_calls == 1, "runtime index evaluated once");
    check_value(bit_value === 1'bx, "side-effecting invalid index");

    inner_index = 0;
    middle_index = 3;
    bit_value = words[outer_index][middle_index][inner_index];
    check_value(bit_value === 1'bx, "middle dimension out of bounds");

    middle_index = 0;
    outer_index = 2;
    bit_value = words[outer_index][middle_index][inner_index];
    check_value(bit_value === 1'bx, "outer dimension out of bounds");

    outer_index = 0;
    inner_index = 4'bxxxx;
    bit_value = words[outer_index][middle_index][inner_index];
    check_value(bit_value === 1'bx, "unknown index");

    $display("PASSED");
  end
endmodule
