// IEEE 1800-2017/2023 12.7.1 with 6.21: the implicit block a declaring
// for-loop creates is one scope, so two declarators may not share a name.
module sv_for_decl_dup_declarator;
  initial for (int d = 0, d = 1; d < 2; d++) ;
endmodule
