module issue767_generate_implicit_scope;
  generate
    if (1) begin : g
      assign w2 = 1'b1;
    end
  endgenerate
  initial begin
    $display("S");
    $display(w2);
    $display("E");
  end
endmodule
