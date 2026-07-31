// An import of a package that was never compiled.
//
// The lexer only produces PACKAGE_IDENTIFIER for a package it has
// already seen, so an unknown name does not match `package_scope' and
// the import used to die as a bare `syntax error'. What the user then
// saw depended on where the import sat, and none of it mentioned the
// import:
//
//   module scope      -> "syntax error" + "Invalid module item."
//   subroutine body   -> "syntax error" + "Syntax error defining function."
//   package scope     -> "syntax error" + "I give up."   (FATAL)
//
// That last one is the worst: one missing file in a compile list
// aborted the parse and took every other diagnostic in the run with it.
// Chasing the OpenTitan DV dependency chain was mostly this.
//
// This is a CE test: the gold pins that all three now name the package
// and that the package-scope case no longer stops the parse -- the
// module below it is still reached and still reports its own import.
package pkg_scope_case;
  import never_compiled_a_pkg::*;
endpackage

module sv_import_unknown_pkg_diag;
  import never_compiled_b_pkg::*;

  function automatic int f(int a);
    import never_compiled_c_pkg::*;
    return a;
  endfunction

  initial $display("FAILED -- should not have compiled");
endmodule
