module issue2845_outer;
  logic v;
  module inner;
    initial begin
      v = 1'b1;
      $display("in %m");
    end
  endmodule
  inner u();
endmodule

module issue2845_nested_module;
  issue2845_outer o();
  initial begin
    #1;
    if (o.v !== 1'b1)
      $fatal(1, "outer variable was not assigned: %b", o.v);
    $display("v=%b", o.v);
  end
endmodule
