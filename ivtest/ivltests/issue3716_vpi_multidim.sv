module tb;
  logic [7:0] matrix [2:3][1:2];
  logic [7:0] cube [1:0][-1:0][4:5];
  logic [7:0] mem [0:3];
  initial begin
    matrix[2][1] = 8'h12; matrix[2][2] = 8'h34;
    matrix[3][1] = 8'h56; matrix[3][2] = 8'h67;
    cube[0][-1][4] = 8'h81; cube[1][0][5] = 8'h9a;
    mem[2] = 8'h67;
    $issue3716_probe;
    if (matrix[2][1] !== 8'hb5 || matrix[3][2] !== 8'h67)
      $display("FAIL: deposit addressed wrong element");
    else
      $display("PASSED");
  end
endmodule
