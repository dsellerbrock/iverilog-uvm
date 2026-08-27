// IEEE 1800-2017/2023 12.7.1: declaration initializers run in source order,
// so an earlier initializer cannot read a later declarator. With no outer
// binding of that name this must be a hard error, not a compile-progress
// warning that silently drops the reference.
module sv_for_decl_after_use;
  initial for (int i = j, j = 1; i < 2; i++, j++) $display("%0d", i);
endmodule
