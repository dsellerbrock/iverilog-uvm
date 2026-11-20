`timescale 1ns/1ns
module top;
  bit clk;
  bit req = 1;

  property p;
    req;
  endproperty
  concurrent_check: cover property (@(posedge clk) p);

  for (genvar n = 1; n <= 2; n++) begin : g
    generated_check: assert property (@(posedge clk) req |-> ##n 1'b0) else ;
  end

  initial if (1'b0) proc_never: assert property (@(posedge clk) 1'b1);
  initial if (1'b0) begin : idle
    immediate_check: cover (1'b1) $fatal(1, "unreachable cover action");
  end

  initial begin
    #1 clk = 1;
    #1 begin
      clk = 0;
      req = 0;
    end
    #1 clk = 1;
    #1 clk = 0;
    #1 clk = 1;
    #1 $finish(0);
  end
endmodule
