module readcmd_counter_branch_equiv;
  localparam logic [1:0] Addr4B = 2'd2;
  logic [4:0] addr_cnt_q, original_d, revised_d;
  logic addr_cnt_set, addr_shift_en;
  logic [1:0] cmdinfo_addr_mode;
  integer cases_checked = 0;

  always_comb begin
    original_d = addr_cnt_q;
    if (addr_cnt_set) begin
      original_d = (cmdinfo_addr_mode == Addr4B) ? 5'd31 : 5'd23;
    end else if (addr_cnt_q == '0) begin
      original_d = addr_cnt_q;
    end else if (addr_shift_en) begin
      original_d = addr_cnt_q - 1'b1;
    end
  end

  always_comb begin
    if (addr_cnt_set) begin
      revised_d = (cmdinfo_addr_mode == Addr4B) ? 5'd31 : 5'd23;
    end else if (addr_cnt_q == '0) begin
      revised_d = addr_cnt_q;
    end else if (addr_shift_en) begin
      revised_d = addr_cnt_q - 1'b1;
    end else begin
      revised_d = addr_cnt_q;
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

  function automatic logic [4:0] count_state(input integer n);
    case (n)
      0: count_state = 0;
      1: count_state = 1;
      2: count_state = 3;
      3: count_state = 31;
      4: count_state = 5'bxxxxx;
      5: count_state = 5'bzzzzz;
    endcase
  endfunction

  function automatic logic [1:0] mode_state(input integer n);
    case (n)
      0: mode_state = 2'd0;
      1: mode_state = Addr4B;
      2: mode_state = 2'bxx;
      3: mode_state = 2'bzz;
    endcase
  endfunction

  initial begin
    for (int q = 0; q < 6; q++) begin
      for (int s = 0; s < 4; s++) begin
        for (int e = 0; e < 4; e++) begin
          for (int m = 0; m < 4; m++) begin
            addr_cnt_q = count_state(q);
            addr_cnt_set = four_state(s);
            addr_shift_en = four_state(e);
            cmdinfo_addr_mode = mode_state(m);
            #1;
            if (original_d !== revised_d)
              $fatal(1, "counter mismatch q=%b set=%b shift=%b mode=%b", addr_cnt_q,
                     addr_cnt_set, addr_shift_en, cmdinfo_addr_mode);
            cases_checked++;
          end
        end
      end
    end
    $display("PASS counter final-value equivalence: %0d four-state cases", cases_checked);
    $finish;
  end
endmodule
