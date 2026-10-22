module d3_output_variable_default;
  int gv;
  function void g(output int o = gv); o = 42; endfunction
  initial begin gv = 0; g(); $display("D3 gv=%0d", gv); end
endmodule
