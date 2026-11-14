module pla_ascending_3313;
  logic [1:2] mem [1:2];
  logic [3:0] bits_in;
  logic [1:2] terms_in, terms_out;
  logic [1:2] result_out;
  logic [0:0] one_mem [0:0];
  logic one_out;
  initial begin
    mem[1] = 2'b10; mem[2] = 2'b01;
    bits_in = 4'b1000; terms_in = 2'b10;
    $sync$or$array(mem, {bits_in[3], bits_in[2]}, terms_out);
    $sync$or$plane(mem, terms_in[1:2], result_out);
    one_mem[0] = 1'b1;
    $sync$or$array(one_mem, bits_in[3], one_out);
    if (terms_out !== 2'b10 || result_out !== 2'b10 || one_out !== 1'b1)
      $fatal(1, "ascending PLA result mismatch");
    $display("PASS");
  end
endmodule
