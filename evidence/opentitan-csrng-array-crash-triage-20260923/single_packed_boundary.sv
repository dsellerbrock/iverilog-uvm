module single_packed_boundary;
  logic [7:0] source_word;
  wire [7:0] words [0:0];
  assign words[0] = {source_word[3:0], source_word[7:4]};

  initial begin
    source_word = 8'h5A;
    #1;
    if (words[0] !== 8'hA5) $fatal(1, "wrong single-packed word");
    $display("PASS single-packed net array word");
    $finish(0);
  end
endmodule
