// Minimal shape of caliptra_top_tb_services.sv's KV_MLKEM_CHECK0.
module packed_compare;
  typedef struct packed { logic [7:0][31:0] sharedkey; } vector_t;
  vector_t vector = '0;
  logic [7:0][31:0] entry = '0;
  logic clk = 0;
  integer failures = 0;
  genvar word, octet;
  generate
    for (word = 0; word < 8; word++) begin
      for (octet = 0; octet < 4; octet++) begin
        check: assert property (@(posedge clk)
          entry[word][octet*8 +: 8] == vector.sharedkey[8-1-word][octet*8 +: 8])
          else failures++;
      end
    end
  endgenerate
  initial begin
    #5;
    entry = '1;
    clk = 1;
    #1;
    if (failures !== 0) $fatal(1, "expected Preponed equality; failures=%0d", failures);
    $display("PASSED");
    $finish;
  end
endmodule
