`begin_keywords "1800-2012"

module main;
  localparam logic [3:0][3:0] Infos = {
    4'b1111, 4'b0101, 4'b1010, 4'b0001
  };

  logic [1:0] index;
  logic       selected_enable;
  logic [2:0] selected_value;

  // OpenTitan indexes a constant packed array in always_comb, then selects a
  // member field from the selected element.
  // The result depends on the runtime index, while the constant data source
  // contributes no sensitivity nexus of its own.
  always_comb begin
    selected_enable = Infos[index][3];
    selected_value = Infos[index][2:0];
  end

  task automatic check(input logic [1:0] idx,
                       input logic expected_enable,
                       input logic [2:0] expected_value);
    index = idx;
    #1;
    if (selected_enable !== expected_enable ||
        selected_value !== expected_value) begin
      $display("FAILED -- index=%0d enable=%b value=%0d expected=%b/%0d",
               index, selected_enable, selected_value,
               expected_enable, expected_value);
      $finish;
    end
  endtask

  (* ivl_synthesis_off *)
  initial begin
    check(2'd0, 1'b0, 3'd1);
    check(2'd1, 1'b1, 3'd2);
    check(2'd2, 1'b0, 3'd5);
    check(2'd3, 1'b1, 3'd7);
    $display("PASSED");
    $finish;
  end
endmodule

`end_keywords
