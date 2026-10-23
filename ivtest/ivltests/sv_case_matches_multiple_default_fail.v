module sv_case_matches_multiple_default_fail;
  initial begin
    case (5) matches
      1: ;
      default: ;
      default: ;
    endcase
  end
endmodule
