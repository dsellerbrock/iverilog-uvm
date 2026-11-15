// IEEE 1800-2023 37.17 details 5 and 18: vpi_iterate(vpiIndex) on a word
// of a variable array returns the index that selects it.
module top;
  logic [1:0] var_arr [3:2];
  reg   [7:0] mem [0:4];
  initial begin
    #0;
    $probe_var_word_index;
    $finish;
  end
endmodule
