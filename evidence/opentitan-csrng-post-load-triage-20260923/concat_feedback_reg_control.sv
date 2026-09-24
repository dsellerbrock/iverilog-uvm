module concat_feedback_reg_control;
  logic [7:0] value;
  wire [1:0][3:0] words [0:0];
  assign words[0] = {value[3:0], value[7:4]};
  initial begin
    value = 8'h5a;
    #1;
    if (words[0] !== 8'ha5) $fatal(1, "bad concat value");
    $display("PASS acyclic concat");
    $finish(0);
  end
endmodule
