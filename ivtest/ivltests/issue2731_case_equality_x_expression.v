module issue2731_case_equality_x_expression;
  logic signed [7:0] value = 8'b000x0001;
  logic signed [7:0] saved;

  initial begin
    saved = +value;
    $display("expr=%b saved=%b expr_case_eq=%0b saved_case_eq=%0b",
             +value, saved, (+value) === 8'hxx, saved === 8'hxx);
    if (!((+value) === 8'hxx) || !(saved === 8'hxx))
      $fatal(1, "case equality must compare X bits identically for expression and stored value");
    $display("PASS");
    $finish;
  end
endmodule
