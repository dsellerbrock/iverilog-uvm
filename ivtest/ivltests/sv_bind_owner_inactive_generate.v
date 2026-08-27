// IEEE 1800-2017/2023 23.11, 27.3/27.4: bind is a generate item and is
// present only in the parameter-specialized conditional/case arm that is
// actually elaborated.
package sv_bind_owner_inactive_generate_counts;
  int parameter_hits;
  int parameter_sum;
  int case_hits;
  int case_sum;
endpackage

module sv_bind_owner_inactive_generate_probe #(
  parameter int KIND = 0
) (input int observed);
  initial begin
    #0;
    if (KIND == 0) begin
      sv_bind_owner_inactive_generate_counts::parameter_hits =
        sv_bind_owner_inactive_generate_counts::parameter_hits + 1;
      sv_bind_owner_inactive_generate_counts::parameter_sum =
        sv_bind_owner_inactive_generate_counts::parameter_sum + observed;
    end else begin
      sv_bind_owner_inactive_generate_counts::case_hits =
        sv_bind_owner_inactive_generate_counts::case_hits + 1;
      sv_bind_owner_inactive_generate_counts::case_sum =
        sv_bind_owner_inactive_generate_counts::case_sum + observed;
    end
  end
endmodule

module sv_bind_owner_inactive_generate_leaf #(
  parameter int TAG = 0
);
endmodule

module sv_bind_owner_parameter_generate_holder #(
  parameter bit ENABLE = 1'b0,
  parameter int TAG = 0
);
  sv_bind_owner_inactive_generate_leaf #(.TAG(TAG)) u();

  if (ENABLE) begin : enabled_arm
    bind u sv_bind_owner_inactive_generate_probe #(.KIND(0))
      parameter_probe(.observed(TAG));
  end
endmodule

module sv_bind_owner_case_generate_holder #(
  parameter int SELECTED = 0,
  parameter int TAG = 0
);
  sv_bind_owner_inactive_generate_leaf #(.TAG(TAG)) u();

  case (SELECTED)
    0: begin : selected_arm
    end
    1: begin : bind_arm
      bind u sv_bind_owner_inactive_generate_probe #(.KIND(1))
        case_probe(.observed(TAG));
    end
  endcase
endmodule

module sv_bind_owner_inactive_generate;
  sv_bind_owner_parameter_generate_holder #(
    .ENABLE(1'b0), .TAG(10)
  ) parameter_off();
  sv_bind_owner_parameter_generate_holder #(
    .ENABLE(1'b1), .TAG(11)
  ) parameter_on();

  sv_bind_owner_case_generate_holder #(
    .SELECTED(0), .TAG(20)
  ) case_off();
  sv_bind_owner_case_generate_holder #(
    .SELECTED(1), .TAG(21)
  ) case_on();

  initial begin
    #1;
    if (sv_bind_owner_inactive_generate_counts::parameter_hits == 1
        && sv_bind_owner_inactive_generate_counts::parameter_sum == 11
        && sv_bind_owner_inactive_generate_counts::case_hits == 1
        && sv_bind_owner_inactive_generate_counts::case_sum == 21)
      $display("PASSED");
    else
      $display("FAILED: parameter=%0d/%0d case=%0d/%0d",
               sv_bind_owner_inactive_generate_counts::parameter_hits,
               sv_bind_owner_inactive_generate_counts::parameter_sum,
               sv_bind_owner_inactive_generate_counts::case_hits,
               sv_bind_owner_inactive_generate_counts::case_sum);
  end
endmodule
