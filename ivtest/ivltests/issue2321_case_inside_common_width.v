module issue2321_case_inside_common_width;
  logic [1:0] b2 = 2'b11;
  bit case_default;

  initial begin
    case (b2) inside
      32'd0, '1: case_default = 0;
      default: case_default = 1;
    endcase

    if (!case_default) $fatal(1, "case-inside item was sized independently");
    if (!(b2 inside {'1})) $fatal(1, "plain inside sizing changed");
    $display("PASSED");
  end
endmodule
