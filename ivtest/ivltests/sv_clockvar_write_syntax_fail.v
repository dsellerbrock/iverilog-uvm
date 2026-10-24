interface sv_clockvar_write_syntax_if(input logic clk);
  logic data;
  clocking cb @(posedge clk);
    output data;
  endclocking
endinterface

module sv_clockvar_write_syntax_fail;
  logic clk = 1'b0;
  sv_clockvar_write_syntax_if bus(clk);

  initial begin
    bus.cb.data = 1'b1;
    bus.cb.data <= #4 1'b0;
  end
endmodule
