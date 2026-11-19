module issue3896_force_concat;
  reg a, b;
  reg [1:0] rhs = 2'b11;

  initial begin
    #1 force {a, b} = rhs;
    $display("%b", {a, b});
    rhs = 2'b01;
    #1 $display("%b", {a, b});
    rhs = 2'b00;
    #1 $display("%b", {a, b});
    release {a, b};
  end
endmodule
