// Recursive replacement must fail before macro input buffers exhaust memory.
`define LOOP `LOOP

module test;
  initial $display(`LOOP);
endmodule
