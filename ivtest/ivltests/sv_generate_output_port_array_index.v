module generated_driver #(
  parameter Width = 6,
  parameter Value = 0
) (
  input  logic             enable_i,
  output logic [Width-1:0] data_o
);
  assign data_o = enable_i ? Width'(Value + 1) : '0;
endmodule

module main(output logic [7:0] words [4]);
  logic [3:0] enabled;

  for (genvar entry_idx = 0; entry_idx < 4; entry_idx++) begin : gen_enabled
    assign enabled[entry_idx] = (entry_idx < 4);
  end

  for (genvar entry_idx = 0; entry_idx < 4; entry_idx++) begin : gen_words
    logic enabled_here;
    assign enabled_here = (entry_idx < 4);
    assign words[entry_idx][7:6] = 2'b00;
    generated_driver #(
      .Value(entry_idx)
    ) driver (
      .enable_i(enabled_here && (entry_idx < 4)),
      .data_o(words[entry_idx][5:0])
    );
  end

  initial begin
    #1;
    if (words[0] !== 8'd1 || words[1] !== 8'd2
        || words[2] !== 8'd3 || words[3] !== 8'd4)
      $display("FAILED -- %h %h %h %h",
               words[0], words[1], words[2], words[3]);
    else
      $display("PASSED");
    $finish;
  end
endmodule
