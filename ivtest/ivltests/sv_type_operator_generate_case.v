module type_case_check #(parameter type T = bit [12:0],
                         parameter bit [1:0] EXPECTED = 2'd0)
                        (output bit matched);
  generate
    case (type(T))
      type(bit [12:0]): begin : fixed_arm
        assign matched = (EXPECTED == 2'd1);
      end
      type(real): begin : real_arm
        assign matched = (EXPECTED == 2'd2);
      end
      default: begin : default_arm
        assign matched = (EXPECTED == 2'd3);
      end
    endcase
  endgenerate
endmodule

module sv_type_operator_generate_case;
  bit fixed_match;
  bit real_match;
  bit default_match;

  type_case_check #(bit [12:0], 2'd1) fixed_type(fixed_match);
  type_case_check #(real, 2'd2) real_type(real_match);
  type_case_check #(int, 2'd3) default_type(default_match);

  initial begin
    #1;
    if (fixed_match && real_match && default_match)
      $display("PASSED");
    else
      $display("FAILED: %b %b %b", fixed_match, real_match, default_match);
  end
endmodule
