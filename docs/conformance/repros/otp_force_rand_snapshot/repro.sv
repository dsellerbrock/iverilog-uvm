// Four calls model one OTP lock macro expansion. SNAPSHOT_UNSAFE shows why
// reusing one persistent RHS signal per force target changes repeated calls.
module otp_force_rand_rhs_repro;
  logic [7:0] p_read, dai_read, p_write, dai_write;
  logic [7:0] s_p_read, s_dai_read, s_p_write, s_dai_write;
  int draws;

  function automatic logic [7:0] rand_non_mubi(input int t_weight = 2,
                                                input int f_weight = 2);
    if (t_weight != 0 || f_weight != 0) $fatal(1, "weights");
    draws++;
    return 8'ha0 + draws;
  endfunction

  task automatic inject();
`ifdef SNAPSHOT_UNSAFE
    s_p_read = rand_non_mubi(.t_weight(0), .f_weight(0));
    if (draws == 5) begin
      if (p_read !== 8'ha5) $fatal(1, "expected linked RHS update");
      $display("UNSAFE: old force changed before replacement");
    end
    force p_read = s_p_read;
    s_dai_read = rand_non_mubi(.t_weight(0), .f_weight(0));
    force dai_read = s_dai_read;
    s_p_write = rand_non_mubi(.t_weight(0), .f_weight(0));
    force p_write = s_p_write;
    s_dai_write = rand_non_mubi(.t_weight(0), .f_weight(0));
    force dai_write = s_dai_write;
`else
    force p_read = rand_non_mubi(.t_weight(0), .f_weight(0));
    force dai_read = rand_non_mubi(.t_weight(0), .f_weight(0));
    force p_write = rand_non_mubi(.t_weight(0), .f_weight(0));
    force dai_write = rand_non_mubi(.t_weight(0), .f_weight(0));
`endif
  endtask

  initial begin
    inject();
    #1;
    if (draws != 4 || p_read !== 8'ha1 || dai_read !== 8'ha2
        || p_write !== 8'ha3 || dai_write !== 8'ha4)
      $fatal(1, "first force: %0d %h %h %h %h",
             draws, p_read, dai_read, p_write, dai_write);
    inject(); // The original four forces remain active until each replacement.
    #1;
    if (draws != 8 || p_read !== 8'ha5 || dai_read !== 8'ha6
        || p_write !== 8'ha7 || dai_write !== 8'ha8)
      $fatal(1, "second force: %0d %h %h %h %h",
             draws, p_read, dai_read, p_write, dai_write);
    $display("PASS: draws=%0d locks=%h %h %h %h",
             draws, p_read, dai_read, p_write, dai_write);
  end
endmodule
