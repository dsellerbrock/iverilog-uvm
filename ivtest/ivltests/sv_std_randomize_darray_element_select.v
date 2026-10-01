// std::randomize(arr) with { foreach (arr[i]) arr[i][1:0] == 0; ... }: a packed
// part or bit select of a local dynamic-array element is a constraint
// operand (IEEE 1800-2017/2023 18.7, 18.5.8). It was reported as "constraint
// form in std::randomize() with-clause is not representable" (OpenTitan chip
// chip_sw_rom_e2e_jtag_debug_vseq).
typedef struct { bit [31:0] start_addr; bit [31:0] end_addr; } rng_t;

module main;
  int errors;
  initial begin
    bit [31:0] addrs[];
    bit [15:0] words[];
    rng_t r1;
    rng_t r2;
    bit ok;
    r1.start_addr = 32'h1000; r1.end_addr = 32'h1fff;
    r2.start_addr = 32'h8000; r2.end_addr = 32'h8fff;

    repeat (5) begin
      ok = std::randomize(addrs) with {
        addrs.size() inside {[5:20]};
        foreach (addrs[i]) {
          addrs[i] inside {[r1.start_addr:r1.end_addr]} ||
          addrs[i] inside {[r2.start_addr:r2.end_addr]};
          addrs[i][1:0] == '0;
        }
      };
      if (!ok) begin $display("FAILED addrs randomize"); errors++; end
      if (addrs.size() < 5 || addrs.size() > 20) begin
        $display("FAILED addrs size %0d", addrs.size()); errors++;
      end
      foreach (addrs[i]) begin
        if (!((addrs[i] >= 32'h1000 && addrs[i] <= 32'h1fff)
              || (addrs[i] >= 32'h8000 && addrs[i] <= 32'h8fff))) begin
          $display("FAILED addrs[%0d]=%h range", i, addrs[i]); errors++;
        end
        if (addrs[i][1:0] !== 2'b00) begin
          $display("FAILED addrs[%0d]=%h alignment", i, addrs[i]); errors++;
        end
      end
    end

    repeat (5) begin
      ok = std::randomize(words) with {
        words.size() == 8;
        foreach (words[i]) { words[i][15] == 1'b1; words[i][3:0] == i[3:0]; }
      };
      if (!ok) begin $display("FAILED words randomize"); errors++; end
      foreach (words[i]) begin
        if (words[i][15] !== 1'b1 || words[i][3:0] !== i[3:0]) begin
          $display("FAILED words[%0d]=%h", i, words[i]); errors++;
        end
      end
    end
    if (errors == 0) $display("PASSED");
  end
endmodule
