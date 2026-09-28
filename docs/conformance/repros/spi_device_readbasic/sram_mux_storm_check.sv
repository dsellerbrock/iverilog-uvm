module sram_mux_reducer;
  typedef struct packed {
    logic req;
    logic [7:0] addr;
  } request_t;
  typedef struct packed {
    logic rvalid;
    logic [7:0] rdata;
  } response_t;

  request_t sub_sram_l2m [2];
  response_t sub_sram_m2l [2];
  request_t flash_sram_l2m, mem_b_l2m;
  response_t flash_sram_m2l, mem_b_m2l;
  logic csb = 1'b1;
  logic read_cmd = 1'b0;
  integer events = 0;

  always_comb begin
    flash_sram_l2m = '{default:'0};
    for (int i = 0; i < 2; i++) begin
      sub_sram_m2l[i] = '{default:'0};
    end
    if (read_cmd) begin
      flash_sram_l2m = sub_sram_l2m[0];
      sub_sram_m2l[0] = flash_sram_m2l;
    end
  end

  always_comb begin
`ifdef PATCHED
    if (!csb) begin
      mem_b_l2m = flash_sram_l2m;
      flash_sram_m2l = mem_b_m2l;
    end else begin
      mem_b_l2m = '{default:'0};
      flash_sram_m2l = '{default:'0};
    end
`else
    mem_b_l2m = '{default:'0};
    flash_sram_m2l = '{default:'0};
    if (!csb) begin
      mem_b_l2m = flash_sram_l2m;
      flash_sram_m2l = mem_b_m2l;
    end
`endif
  end

  always @(flash_sram_l2m or flash_sram_m2l or mem_b_l2m or sub_sram_m2l[0]) begin
    if ($time >= 1) begin
      events = events + 1;
      if (events <= 8 || events == 16 || events == 32 || events == 64)
        $display("PROBE event=%0d t=%0t flash_l2m=%h flash_m2l=%h mem_l2m=%h sub_m2l=%h", events,
                 $time, flash_sram_l2m, flash_sram_m2l, mem_b_l2m, sub_sram_m2l[0]);
      if (events == 100) $fatal(1, "zero-time SRAM mux storm");
    end
  end

  initial begin
    sub_sram_l2m[0] = '{req:1'b0, addr:8'h23};
    sub_sram_l2m[1] = '0;
    mem_b_m2l = '{rvalid:1'b0, rdata:8'ha5};
    #1;
    csb = 1'b0;
    read_cmd = 1'b1;
    sub_sram_l2m[0].req = 1'b1;
    #1;
    $display("PASS t=%0t events=%0d", $time, events);
    $finish;
  end
endmodule
