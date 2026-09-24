module net_array_candidate;
  logic [1:0][3:0] source_word;
  wire [1:0][3:0] words [0:0];
  assign words[0] = source_word;

  initial begin
    source_word = 8'hA5;
    #1;
    if (words[0] !== 8'hA5) $fatal(1, "wrong net array word");
    $display("PASS net array word");
    $finish(0);
  end
endmodule
