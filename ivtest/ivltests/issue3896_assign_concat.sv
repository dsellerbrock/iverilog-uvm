module issue3896_assign_concat;
  reg a, b;
  reg [1:0] rhs = 2'b10;

  initial begin
    #1 assign {a, b} = rhs;
    if ({a, b} !== 2'b10) $fatal(1, "Initial assign");
    rhs = 2'b01;
    #1 $display("%b", {a, b});
    deassign {a, b};
    rhs = 2'b10;
    #1 $display("%b", {a, b});
  end
endmodule
