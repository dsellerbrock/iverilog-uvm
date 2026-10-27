module p12_05_4_case_inside_asymmetry;
  logic [2:0] status;
  integer matched;

  initial begin
    status = 3'b0x0;
    case (status) inside
      3'b0?0: matched = 1;
      default: matched = 0;
    endcase
    if (matched !== 1) $fatal(1, "FAIL item wildcard did not match X");

    status = 3'b0z0;
    case (status) inside
      3'b0?0: matched = 1;
      default: matched = 0;
    endcase
    if (matched !== 1) $fatal(1, "FAIL item wildcard did not match Z");

    status = 3'b00x;
    case (status) inside
      3'b0?0: matched = 1;
      default: matched = 0;
    endcase
    if (matched !== 0) $fatal(1, "FAIL X in case expression matched known item");

    $display("PASS asymmetric case-inside wildcard matching");
  end
endmodule
