module pla_descending_3313;
  logic [1:3] mem [1:2];
  logic [1:3] desc_rows [2:1];
  logic [3:1] desc_word [1:2];
  logic [1:3] input_terms;
  logic [3:1] desc_input;
  logic [1:2] output_terms;
  logic [2:1] desc_output;
  initial begin
    $async$or$array(desc_rows, input_terms, output_terms);
    $sync$and$plane(desc_word, input_terms, output_terms);
    $sync$nor$array(mem, desc_input, output_terms);
    $async$nand$plane(mem, input_terms, desc_output);
    $sync$or$array(mem, desc_input[3:2], output_terms);
    $sync$or$array(mem, input_terms, desc_output[2:1]);
  end
endmodule
