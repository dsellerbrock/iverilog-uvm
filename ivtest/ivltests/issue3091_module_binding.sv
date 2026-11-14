module leaf;
  initial $display("BINDING=%l");
endmodule

module top;
  leaf u();
  initial $inspect_binding;
endmodule
