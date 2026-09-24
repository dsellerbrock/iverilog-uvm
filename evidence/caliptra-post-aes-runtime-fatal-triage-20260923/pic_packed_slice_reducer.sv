// Isolate the level-zero assignment in pinned el2_pic_ctrl.sv:408.
module pic_packed_slice_reducer;
  logic [31:0][3:0] leaves;
  logic [33:0][3:0] one_level;
  logic [1:0][33:0][3:0] two_levels;
  logic [1:0][33:0][3:0] whole_array;
  logic [1:0][33:0][3:0] direct_link;
  logic [1:0][33:0][3:0] port_link;
  assign one_level = {{8{1'b0}}, leaves};
  assign two_levels[0][33:0] = {{8{1'b0}}, leaves};
  assign whole_array = {136'b0, {{8{1'b0}}, leaves}};
  assign direct_link[0] = {{8{1'b0}}, leaves};
  assign direct_link[1][0] = direct_link[0][0];
  assign port_link[0] = {{8{1'b0}}, leaves};
  pic_pass pass1 (.a(port_link[0][0]), .y(port_link[1][0]));
  initial begin
    leaves = '0;
    #1;
    $display("known leaves=%b one_level=%b nested_slice=%b whole_array=%b direct=%b/%b port=%b/%b",
             leaves[0], one_level[0], two_levels[0][0], whole_array[0][0],
             direct_link[0][0], direct_link[1][0], port_link[0][0], port_link[1][0]);
    if (one_level[0] !== 4'b0 || whole_array[0][0] !== 4'b0)
      $fatal(1, "positive controls failed");
    if (two_levels[0][0] === 4'b0 && direct_link[0][0] === 4'b0 &&
        direct_link[1][0] === 4'b0 && port_link[0][0] === 4'b0 &&
        port_link[1][0] === 4'b0)
      $display("PASS nested packed slice");
    else
      $fatal(1, "nested packed slice lost known driver");
  end
endmodule

module pic_pass(input logic [3:0] a, output logic [3:0] y);
  assign y = a;
endmodule
