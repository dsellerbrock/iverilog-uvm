module test;
  bit clk = 0;
  bit [1:0] sel;
  bit a = 1, b, c;
  int failures;

  always #5 clk = ~clk;

  property p_case;
    @(posedge clk)
    case (sel)
      2'b00: a;
      2'b01: b;
      default: c;
    endcase;
  endproperty

  assert property (p_case) else failures++;

  initial begin
    @(negedge clk); sel = 2'b00; a = 1;
    @(posedge clk); #1;
    @(negedge clk); sel = 2'b01; b = 1;
    @(posedge clk); #1;
    @(negedge clk); sel = 2'b10; c = 1;
    @(posedge clk); #1;
    @(negedge clk); sel = 2'b11; c = 0;
    @(posedge clk); #1;
    if (failures != 1) begin
      $display("FAIL: case failures=%0d (expected 1)", failures);
      $fatal(1);
    end
    $display("PASSED: §16.12.16 case selected arms and default");
    $finish;
  end
endmodule
