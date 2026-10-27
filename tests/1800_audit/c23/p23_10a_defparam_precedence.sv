module leaf #(parameter int P = 1);
endmodule

module top;
  leaf #(.P(2)) u();
  defparam u.P = 3;
  initial begin
    #1;
    if (u.P != 3) $fatal(1, "defparam did not override instance parameter");
    $display("PASS: defparam precedence");
  end
endmodule
