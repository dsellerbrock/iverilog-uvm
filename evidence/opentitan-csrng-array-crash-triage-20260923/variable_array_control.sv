module variable_array_control;
  logic [7:0] source_word;
  logic [1:0][3:0] words [0:0];

  initial begin
    source_word = 8'h5A;
    words[0] = {source_word[3:0], source_word[7:4]};
    if (words[0] !== 8'hA5) $fatal(1, "wrong variable array word");
    $display("PASS variable array word");
    $finish(0);
  end
endmodule
