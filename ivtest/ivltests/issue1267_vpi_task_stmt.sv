module top;
  task empty; endtask
  task multi; $display("a"); $display("b"); endtask
  initial begin #0; $probe(); $finish; end
endmodule
