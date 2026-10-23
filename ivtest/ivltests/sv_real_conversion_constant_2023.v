module main;
  localparam real PR = $bitstoreal(64'h4000000000000000);
  localparam [63:0] RB = $realtobits(1.5);
  localparam [31:0] SB = $shortrealtobits(1.5);
  localparam shortreal SR = $bitstoshortreal(32'h3fc00000);
  localparam real R2 = $bitstoreal($realtobits(2.5));

  initial begin
    if (PR == 2.0 && RB == 64'h3ff8000000000000 &&
        SB == 32'h3fc00000 && SR == 1.5 && R2 == 2.5)
      $display("PASSED");
    else
      $display("FAILED %0.1f %h %h %0.1f %0.1f", PR, RB, SB, SR, R2);
  end
endmodule
