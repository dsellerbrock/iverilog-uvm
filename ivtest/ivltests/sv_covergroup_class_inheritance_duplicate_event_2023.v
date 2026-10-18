module test;
  bit clk;
  class B;
    bit a;
    covergroup cg @(posedge clk);
      cp_a: coverpoint a;
    endgroup
    function new; cg = new; endfunction
  endclass
  class D extends B;
    covergroup extends cg @(negedge clk);
    endgroup : cg
  endclass
  initial $display("unexpected acceptance");
endmodule
