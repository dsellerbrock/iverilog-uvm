module issue1526_sink(input logic signed [7:0] p);
  initial begin
    #1 $display("PORT_INPUT_VALUE %0d %h", p, p);
  end
endmodule

module issue1526_port_expr_context;
  logic signed [3:0] a, b;

  initial begin
    a = 7;
    b = 1;
  end

  issue1526_sink u(.p(a+b));
endmodule
