// IEEE 1800-2017/2023 23.11, 27.3/27.4: a contained bind becomes live with
// its elaborated owner. Loading its -y-only bound type can append a
// compilation-unit bind, which must join the same activation closure.
package sv_bind_owner_library_cu_closure_counts;
  int hits;
endpackage

module sv_bind_owner_library_cu_closure_probe;
  initial sv_bind_owner_library_cu_closure_counts::hits =
    sv_bind_owner_library_cu_closure_counts::hits + 1;
endmodule

module sv_bind_owner_library_cu_closure_target;
endmodule

module sv_bind_owner_library_cu_closure_holder;
  // Resolving this live contained directive loads the dependency from -y.
  // That library source contributes the compilation-unit bind under test.
  bind sv_bind_owner_library_cu_closure_target
    sv_bind_owner_library_cu_dependency helper();
endmodule

module sv_bind_owner_library_cu_closure;
  sv_bind_owner_library_cu_closure_holder owner();
  sv_bind_owner_library_cu_closure_target target();

  initial begin
    #1;
    if (sv_bind_owner_library_cu_closure_counts::hits == 1)
      $display("PASSED");
    else
      $display("FAILED: hits=%0d",
               sv_bind_owner_library_cu_closure_counts::hits);
  end
endmodule
