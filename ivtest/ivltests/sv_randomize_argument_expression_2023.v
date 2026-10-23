class randomize_argument_expression;
  rand int x;
endclass

module test;
  randomize_argument_expression a;
  initial begin
    a = new;
    a.randomize(x + 1);
  end
endmodule
