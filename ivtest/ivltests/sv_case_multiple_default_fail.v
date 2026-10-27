module sv_case_multiple_default_fail;
  initial begin
    case (5)
      1: ;
      default: ;
      default: ;
    endcase
  end
endmodule
