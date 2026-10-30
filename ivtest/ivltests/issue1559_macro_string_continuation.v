`define S "left\
right"
module issue1559_macro_string_continuation;
  initial begin
    $display("S=[%s]", `S);
    $finish;
  end
endmodule
