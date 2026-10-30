module sink(input logic signed [7:0] p);
  initial begin
    #1;
    if (p !== 8'sd8) begin
      $display("FAILED: %0d %h", p, p);
      $finish;
    end
    $display("PORT_INPUT_VALUE %0d %h", p, p);
    #1 $finish;
  end
endmodule

module main;
  logic signed [3:0] a, b;
  initial begin a = 7; b = 1; end
  sink u(.p(a+b));
endmodule
