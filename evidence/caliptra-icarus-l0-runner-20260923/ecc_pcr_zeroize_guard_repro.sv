// Focused model of ECC_CTRL.PCR_SIGN, the busy transition, and ZEROIZE.
module tb;
  parameter bit ZEROIZE_GUARD = 0;
  parameter bit MUTATE = 0;
  parameter bit MUTATE_ON_ZEROIZE = 0;
  bit clk = 0;
  always #5 clk = ~clk;
  bit reset_n = 0;
  bit command_write = 0;
  bit zeroize_reg = 0;
  bit mutate_key = 0;
  bit pcr_sign_mode = 0;
  bit busy = 0;
  wire ecc_ready_reg = !busy;
  logic [383:0] privkey_reg = '0;
  int failures = 0;

  always_ff @(posedge clk) begin
    if (!reset_n) begin
      pcr_sign_mode <= 0;
      busy <= 0;
      privkey_reg <= '0;
    end else begin
      pcr_sign_mode <= command_write;
      if (pcr_sign_mode) begin
        busy <= 1;
        privkey_reg <= 384'h12345678;
      end
      if (zeroize_reg) privkey_reg <= '0;
      if (mutate_key) privkey_reg <= zeroize_reg ? 384'hdeadbeef : 384'hcafebabe;
    end
  end

  generate if (ZEROIZE_GUARD) begin : guarded
    a_stable: assert property (@(posedge clk) disable iff (!reset_n)
      (ecc_ready_reg || $past(ecc_ready_reg) ||
       ($past(zeroize_reg) && privkey_reg == '0) ||
       $stable(privkey_reg)))
      else failures++;
  end else begin : unguarded
    a_stable: assert property (@(posedge clk) disable iff (!reset_n)
      (ecc_ready_reg || $past(ecc_ready_reg) || $stable(privkey_reg)))
      else failures++;
  end endgenerate

  initial begin
    repeat (2) @(negedge clk);
    reset_n = 1;
    command_write = 1;
    @(negedge clk);
    command_write = 0;
    repeat (4) @(negedge clk);
    zeroize_reg = 1;
    mutate_key = MUTATE_ON_ZEROIZE;
    @(negedge clk);
    zeroize_reg = 0;
    mutate_key = 0;
    repeat (3) @(negedge clk);
    if (MUTATE) begin
      mutate_key = 1;
      @(negedge clk);
      mutate_key = 0;
    end
    repeat (3) @(negedge clk);
    if (failures != (ZEROIZE_GUARD ? (MUTATE_ON_ZEROIZE + MUTATE) : (1 + MUTATE)))
      $fatal(1, "unexpected failures=%0d guard=%0d mutate=%0d on_zeroize=%0d",
             failures, ZEROIZE_GUARD, MUTATE, MUTATE_ON_ZEROIZE);
    $display("PASSED guard=%0d mutate=%0d on_zeroize=%0d failures=%0d",
             ZEROIZE_GUARD, MUTATE, MUTATE_ON_ZEROIZE, failures);
    $finish;
  end
endmodule
