// A generated packed-struct double select, as in Caliptra KV_MLKEM_CHECK0,
// must use the Preponed value at the assertion clock (IEEE 1800 16.5.1).
module sv_assert_nested_packed_preponed;
  typedef struct packed { logic [7:0][31:0] sharedkey; } vector_t;
  vector_t vector = '0;
  logic [7:0][31:0] entry = '0;
  logic [7:0] flat = '0;
  logic clk = 0;
  integer nested_failures = 0;
  integer flat_failures = 0;
  genvar word, octet;
  generate
    for (word = 0; word < 8; word++) begin
      for (octet = 0; octet < 4; octet++) begin
        check: assert property (@(posedge clk)
          entry[word][octet*8 +: 8] == vector.sharedkey[8-1-word][octet*8 +: 8])
          else nested_failures++;
      end
    end
  endgenerate
  control: assert property (@(posedge clk) flat == 8'hff)
    else flat_failures++;

  initial begin
    #5;
    entry = '1;
    flat = '1;
    clk = 1;
    #1;
    $display("COUNTS nested=%0d flat=%0d", nested_failures, flat_failures);
    if (nested_failures !== 0 || flat_failures !== 1)
      $fatal(1, "packed select was read live, or assertions did not execute");
    $display("PASSED");
  end
endmodule
