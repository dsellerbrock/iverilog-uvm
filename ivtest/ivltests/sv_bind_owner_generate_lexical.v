// IEEE 1800-2017/2023 23.11, 27.3: a bind directive inside a generate
// block resolves an unqualified target from that generate block's lexical
// scope, before searching the containing module.
package sv_bind_owner_generate_lexical_counts;
  int direct_hits;
  int generate_hits;
  int errors;
endpackage

module sv_bind_owner_generate_lexical_probe(input int observed);
  initial begin
    #0;
    case (observed)
      10: sv_bind_owner_generate_lexical_counts::direct_hits =
            sv_bind_owner_generate_lexical_counts::direct_hits + 1;
      20: sv_bind_owner_generate_lexical_counts::generate_hits =
            sv_bind_owner_generate_lexical_counts::generate_hits + 1;
      default: sv_bind_owner_generate_lexical_counts::errors =
            sv_bind_owner_generate_lexical_counts::errors + 1;
    endcase
  end
endmodule

module sv_bind_owner_generate_lexical_leaf #(
  parameter int TAG = 0
);
endmodule

module sv_bind_owner_generate_lexical_holder;
  sv_bind_owner_generate_lexical_leaf #(.TAG(10)) u();

  if (1) begin : g
    sv_bind_owner_generate_lexical_leaf #(.TAG(20)) u();
    bind u sv_bind_owner_generate_lexical_probe bp(.observed(TAG));
  end
endmodule

module sv_bind_owner_generate_lexical;
  sv_bind_owner_generate_lexical_holder holder();

  initial begin
    #1;
    if (sv_bind_owner_generate_lexical_counts::direct_hits == 0
        && sv_bind_owner_generate_lexical_counts::generate_hits == 1
        && sv_bind_owner_generate_lexical_counts::errors == 0)
      $display("PASSED");
    else
      $display("FAILED: direct=%0d generate=%0d errors=%0d",
               sv_bind_owner_generate_lexical_counts::direct_hits,
               sv_bind_owner_generate_lexical_counts::generate_hits,
               sv_bind_owner_generate_lexical_counts::errors);
  end
endmodule
