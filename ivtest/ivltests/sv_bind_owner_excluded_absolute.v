// IEEE 1800-2017/2023 23.11: a bind declared in a module is active only
// for elaborated instances of that containing module. The uninstantiated
// binder below must not affect the selected top.
package sv_bind_owner_excluded_absolute_counts;
  int hits;
endpackage

module sv_bind_owner_excluded_absolute_probe;
  initial sv_bind_owner_excluded_absolute_counts::hits =
    sv_bind_owner_excluded_absolute_counts::hits + 1;
endmodule

module sv_bind_owner_excluded_absolute_leaf;
endmodule

module sv_bind_owner_excluded_absolute;
  sv_bind_owner_excluded_absolute_leaf u();

  initial begin
    #1;
    if (sv_bind_owner_excluded_absolute_counts::hits == 0)
      $display("PASSED");
    else
      $display("FAILED: excluded bind produced %0d hit(s)",
               sv_bind_owner_excluded_absolute_counts::hits);
  end
endmodule

module sv_bind_owner_excluded_absolute_binder;
  bind sv_bind_owner_excluded_absolute.u
    sv_bind_owner_excluded_absolute_probe bp();
endmodule
