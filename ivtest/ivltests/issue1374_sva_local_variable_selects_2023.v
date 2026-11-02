module issue1374_sva_local_variable_selects;
  logic clk = 0, start = 0, check = 0;
  logic [7:0] payload = 0;
  logic [1:0] values [0:3];
  logic [1:0] select_index = 0;
  always #5 clk = ~clk;
  sequence value_access;
    int index;
    (start, index = select_index) ##1 (check && index == 1);
  endsequence
  sequence bit_access;
    int index;
    (start, index = select_index) ##1 (check && payload[index]);
  endsequence
  sequence part_access;
    int index;
    (start, index = select_index) ##1 (check && payload[index +: 2] == 2'b01);
  endsequence
  sequence array_access;
    int index;
    (start, index = select_index) ##1 (check && values[index] == 2'b10);
  endsequence
  cv_value: cover property (@(posedge clk) value_access);
  cv_bit: cover property (@(posedge clk) bit_access);
  cv_part: cover property (@(posedge clk) part_access);
  cv_array: cover property (@(posedge clk) array_access);
  initial begin
    @(negedge clk) begin start = 1; select_index = 1; payload = 8'h02; values[1] = 2'b10; values[2] = 0; end
    @(negedge clk) begin start = 0; select_index = 2; check = 1; end
    @(negedge clk) check = 0;
    @(negedge clk);
    $display("local variable select counts=%0d/%0d/%0d/%0d",
             _ivl_sva0_cnt0, _ivl_sva1_cnt0, _ivl_sva2_cnt0, _ivl_sva3_cnt0);
    $finish(0);
  end
endmodule
