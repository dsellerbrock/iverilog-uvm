// A constant $sformatf("%m") used as a typed parameter initializer is
// evaluated in each module instance's scope, not once in the module
// definition's scope.
module localparam_sformatf_leaf #(parameter string EXPECT = "");
  localparam string MSG_ID = $sformatf("%m");

  initial begin
    if (MSG_ID != EXPECT) begin
      $display("FAILED: got <%s>, expected <%s>", MSG_ID, EXPECT);
      $finish;
    end
  end
endmodule

module top;
  localparam_sformatf_leaf #(.EXPECT("top.first")) first();
  localparam_sformatf_leaf #(.EXPECT("top.second")) second();

  initial begin
    #1;
    $display("PASSED");
  end
endmodule
