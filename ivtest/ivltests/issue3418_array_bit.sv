module issue3418_array_bit;
  logic [1:0] m [0:1];
  logic [0:1] ascending [1:2];
  logic value;
  assign m[0][0] = value;
  assign m[1][1] = value;
  assign ascending[2][0] = value;
  initial begin
    value = 1;
    m[0][1] = 0;
    m[1][0] = 0;
    ascending[2][1] = 0;
    #1;
    if (m[0] !== 2'b01 || m[1] !== 2'b10 || ascending[2] !== 2'b10)
      $fatal(1, "incorrect initial values");
    value = 0;
    m[0][1] = 1;
    m[1][0] = 1;
    ascending[2][1] = 1;
    #1;
    if (m[0] !== 2'b10 || m[1] !== 2'b01 || ascending[2] !== 2'b01)
      $fatal(1, "incorrect updated values");
    $display("PASS");
  end
endmodule
