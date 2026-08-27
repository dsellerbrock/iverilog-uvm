// IEEE 1800-2017/2023 23.11/27.5: a relative bind path is resolved in each
// elaborated owner occurrence. Inactive same-named conditional-generate
// alternatives do not constrain the active target's module type.
package bind_duplicate_type_counts;
  int a_hits;
  int b_hits;
  int errors;
endpackage

module bind_duplicate_type_probe(input int observed);
  initial begin
    #0;
    case (observed)
      1: bind_duplicate_type_counts::a_hits =
           bind_duplicate_type_counts::a_hits + 1;
      2: bind_duplicate_type_counts::b_hits =
           bind_duplicate_type_counts::b_hits + 1;
      default: bind_duplicate_type_counts::errors =
                 bind_duplicate_type_counts::errors + 1;
    endcase
  end
endmodule

module bind_duplicate_type_a;
  localparam int TAG = 1;
endmodule

module bind_duplicate_type_b;
  localparam int TAG = 2;
endmodule

module bind_duplicate_type_holder #(parameter bit TAKE_A = 1'b1);
  if (TAKE_A) begin : selected
    bind_duplicate_type_a child();
  end else begin : selected
    bind_duplicate_type_b child();
  end

  bind selected.child bind_duplicate_type_probe attached(.observed(TAG));
endmodule

module sv_bind_conditional_different_types;
  bind_duplicate_type_holder #(.TAKE_A(1'b1)) a_holder();
  bind_duplicate_type_holder #(.TAKE_A(1'b0)) b_holder();

  initial begin
    #1;
    if (bind_duplicate_type_counts::a_hits == 1
        && bind_duplicate_type_counts::b_hits == 1
        && bind_duplicate_type_counts::errors == 0)
      $display("PASSED");
    else
      $display("FAILED: a=%0d b=%0d errors=%0d",
               bind_duplicate_type_counts::a_hits,
               bind_duplicate_type_counts::b_hits,
               bind_duplicate_type_counts::errors);
  end
endmodule
