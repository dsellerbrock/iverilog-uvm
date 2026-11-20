module gate_leaf;
  initial $display("direct: %l %L");
endmodule

module bound_leaf #(parameter DELAY = 1);
  initial begin : show_binding
    #DELAY $display("configured: %l %L %m");
  end
endmodule

module branch_body;
  bound_leaf #(.DELAY(2)) u();
  initial #3 $display("branch: %l");
endmodule

config inner_cfg;
  design gateLib.branch_body;
endconfig
