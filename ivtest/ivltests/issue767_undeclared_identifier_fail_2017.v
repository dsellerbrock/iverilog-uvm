module undeclared_procedural;
  initial $display(w2);
endmodule

module undeclared_generate;
  generate
    if (1) begin : generated
      wire local_net;
    end
  endgenerate

  initial $display(local_net);
endmodule
