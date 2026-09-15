module sv_const_mixed_equality;
  function automatic int checked;
    int unsigned u = 32'd97;
    int signed minus_one = -1;
    logic [31:0] xword = 32'h0000_00x1;
    logic [31:0] zword = 32'h0000_00z1;
    if (!(u == "a") || !("a" == u) || u != "a") return 0;
    if (!(u === "a") || u !== "a") return 0;
    if (minus_one == 8'hff || !(minus_one == 8'shff)) return 0;
    if ((xword == 8'hx1) !== 1'bx) return 0;
    if (!(xword === 8'hx1) || xword !== 8'hx1) return 0;
    if ((zword != 8'hz1) !== 1'bx) return 0;
    if (!(zword === 8'hz1) || zword !== 8'hz1) return 0;
    if (!(32'h34 ==? 8'h?4) || !(8'h34 ==? 32'h0000_00?4)) return 0;
    if (32'h134 ==? 8'h?4) return 0;
    return 1;
  endfunction
  localparam int OK = checked();
  initial begin
    if (!OK || !checked()) $fatal(1, "mixed equality mismatch");
    $display("PASSED");
  end
endmodule
