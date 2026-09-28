module sram_mux_branch_equiv;
  typedef struct packed { logic req; logic [7:0] addr; } request_t;
  typedef struct packed { logic rvalid; logic [7:0] rdata; } response_t;
  localparam logic [1:0] FlashMode = 2'd0, PassThrough = 2'd1;

  logic csb, cfg_tpm_en;
  logic [1:0] spi_mode;
  request_t flash_sram_l2m, tpm_sram_l2m;
  response_t mem_b_m2l;
  request_t old_mem_b_l2m, new_mem_b_l2m;
  response_t old_flash_sram_m2l, old_tpm_sram_m2l;
  response_t new_flash_sram_m2l, new_tpm_sram_m2l;
  integer cases_checked = 0;

  // Original OpenTitan combinational block, disconnected from its upstream mux.
  always_comb begin
    old_mem_b_l2m = '{default:'0};
    old_flash_sram_m2l = '{default:'0};
    old_tpm_sram_m2l = '{default:'0};
    if (!csb && ((spi_mode == FlashMode) || (spi_mode == PassThrough))) begin
      old_mem_b_l2m = flash_sram_l2m;
      old_flash_sram_m2l = mem_b_m2l;
    end else if (cfg_tpm_en) begin
      old_mem_b_l2m = tpm_sram_l2m;
      old_tpm_sram_m2l = mem_b_m2l;
    end
  end

  // Proposed replacement: one assignment to each output on each branch.
  always_comb begin
    if (!csb && ((spi_mode == FlashMode) || (spi_mode == PassThrough))) begin
      new_mem_b_l2m = flash_sram_l2m;
      new_flash_sram_m2l = mem_b_m2l;
      new_tpm_sram_m2l = '0;
    end else if (cfg_tpm_en) begin
      new_mem_b_l2m = tpm_sram_l2m;
      new_flash_sram_m2l = '0;
      new_tpm_sram_m2l = mem_b_m2l;
    end else begin
      new_mem_b_l2m = '0;
      new_flash_sram_m2l = '0;
      new_tpm_sram_m2l = '0;
    end
  end

  function automatic logic four_state(input integer n);
    case (n)
      0: four_state = 1'b0;
      1: four_state = 1'b1;
      2: four_state = 1'bx;
      3: four_state = 1'bz;
    endcase
  endfunction

  function automatic logic [1:0] mode_state(input integer n);
    case (n)
      0: mode_state = FlashMode;
      1: mode_state = PassThrough;
      2: mode_state = 2'd2;
      3: mode_state = 2'bxx;
      4: mode_state = 2'bzz;
    endcase
  endfunction

  initial begin
    flash_sram_l2m = '{req:1'b1, addr:8'b10xz_0101};
    tpm_sram_l2m = '{req:1'bx, addr:8'b01zx_1010};
    mem_b_m2l = '{rvalid:1'bz, rdata:8'b1x0z_1100};
    for (int c = 0; c < 4; c++) begin
      for (int t = 0; t < 4; t++) begin
        for (int m = 0; m < 5; m++) begin
          csb = four_state(c);
          cfg_tpm_en = four_state(t);
          spi_mode = mode_state(m);
          #1;
          if (old_mem_b_l2m !== new_mem_b_l2m ||
              old_flash_sram_m2l !== new_flash_sram_m2l ||
              old_tpm_sram_m2l !== new_tpm_sram_m2l)
            $fatal(1, "mismatch csb=%b tpm=%b mode=%b", csb, cfg_tpm_en, spi_mode);
          cases_checked++;
        end
      end
    end
    $display("PASS branch final-value equivalence: %0d four-state cases", cases_checked);
    $finish;
  end
endmodule
