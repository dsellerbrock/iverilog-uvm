// Behavioral-only: does not claim synthesis support for function-call selectors.
module dynamic_word_part_selector_once_behavioral;
  logic [7:0] mem [0:1]; logic clk=0; integer calls=0; logic [2:0] part=4;
  function automatic integer word_once; calls=calls+1; return 1; endfunction
  always @(posedge clk) mem[word_once()][part +: 4] <= 4'ha;
  initial begin #1 clk=1; #1 clk=0;
    if(calls!=1 || mem[1]!==8'hax || mem[0]!==8'hxx)
      $fatal(1,"selector calls=%0d mem=%h,%h",calls,mem[0],mem[1]);
    $display("PASS"); $finish(0);
  end
endmodule
