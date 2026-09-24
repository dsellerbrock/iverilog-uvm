module word_driver(input wire [1:0][3:0] data, output wire [1:0][3:0] words [0:0]);
  assign words[0] = data;
endmodule

module net_array_port_candidate;
  logic [1:0][3:0] source_word;
  wire [1:0][3:0] words [0:0];
  word_driver u_driver(.data(source_word), .words(words));

  initial begin
    source_word = 8'hA5;
    #1;
    if (words[0] !== 8'hA5) $fatal(1, "wrong net array word");
    $display("PASS net array port word");
    $finish(0);
  end
endmodule
