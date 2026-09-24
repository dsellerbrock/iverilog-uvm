// Caliptra's KV_MLKEM_CHECK0 compares nested selects of a packed-struct member.
// IEEE 1800-2017/2023 16.5.1 requires the value before the clock time slot.
module packed_struct_preponed;
  typedef struct packed { logic [1:0][7:0] sharedkey; } vector_t;
  vector_t vector = '0;
  logic [15:0] flat = '0;
  logic clk = 0;
  integer nested_fail = 0;
  integer flat_fail = 0;

  nested: assert property (@(posedge clk) vector.sharedkey[0][7:0] == 8'hff)
    else nested_fail++;
  control: assert property (@(posedge clk) flat[7:0] == 8'hff)
    else flat_fail++;

  initial begin
    #5;
    vector.sharedkey[0] = 8'hff;
    flat[7:0] = 8'hff;
    clk = 1;
    #1;
    if (nested_fail !== 1 || flat_fail !== 1)
      $fatal(1, "Preponed mismatch: nested=%0d flat=%0d", nested_fail, flat_fail);
    $display("PASSED");
    $finish;
  end
endmodule
