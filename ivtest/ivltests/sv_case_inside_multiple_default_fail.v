module sv_case_inside_multiple_default_fail;
  initial begin
    case (5) inside
      1: ;
      default: ;
      default: ;
    endcase
  end
endmodule
