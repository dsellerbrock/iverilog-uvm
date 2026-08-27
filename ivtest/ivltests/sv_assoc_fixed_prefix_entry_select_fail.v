// IEEE 1800-2017/2023: after selecting the fixed prefix and associative key,
// selecting a packed bit of the entry is legal but remains a loud boundary.
module main;
  logic [7:0] packed_values[1:2][string];

  initial begin
    packed_values[1]["word"][3] = 1'b1;
  end
endmodule
