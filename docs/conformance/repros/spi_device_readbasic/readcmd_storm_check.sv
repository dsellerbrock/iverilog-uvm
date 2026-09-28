`timescale 1ns/1ps
module comb_feedback_unique_case_reducer;
  logic [4:0] addr_cnt_q = 4;
  logic [4:0] addr_cnt_d;
  logic addr_shift_en;
  logic addr_ready_in_word;
  logic sram_req;
  logic mode = 0;
  integer events = 0;

  assign addr_ready_in_word = (addr_cnt_d == 5'd2);

  always_comb begin
`ifdef PATCHED
    if (addr_shift_en) addr_cnt_d = addr_cnt_q - 1'b1;
    else addr_cnt_d = addr_cnt_q;
`else
    addr_cnt_d = addr_cnt_q;
    if (addr_shift_en) addr_cnt_d = addr_cnt_q - 1'b1;
`endif
  end

  always_comb begin
    addr_shift_en = 0;
    sram_req = 0;
    if (!mode) begin
      addr_shift_en = 1;
      if (addr_ready_in_word) sram_req = 1;
      unique casez (mode)
        1'b0: ;
        1'b1: ;
      endcase
    end
  end

  always @(addr_cnt_d or addr_ready_in_word or addr_shift_en or sram_req) begin
    if ($time >= 1) begin
      events = events + 1;
      if (events == 100) $fatal(1, "readcmd event storm");
    end
  end

  initial begin
    #1ns addr_cnt_q = 3;
    #1ns;
    $display("PASS events=%0d", events);
    $finish;
  end
endmodule
