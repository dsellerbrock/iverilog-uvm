// IEEE 1800-2017/2023 23.11, 27.3/27.4: a bind in an unselected generate arm
// is absent. Its -y-only bound type is deliberately malformed; an inactive
// directive must neither load that file nor report its diagnostics.
package sv_bind_owner_inactive_library_counts;
  int hits;
endpackage

module sv_bind_owner_inactive_library_probe;
  initial sv_bind_owner_inactive_library_counts::hits =
    sv_bind_owner_inactive_library_counts::hits + 1;
endmodule

module sv_bind_owner_inactive_library_target;
endmodule

module sv_bind_owner_inactive_library_holder;
  if (1'b0) begin : inactive
    bind sv_bind_owner_inactive_library_target
      sv_bind_owner_inactive_library_broken never_loaded();
  end
endmodule

// A live control bind proves ordinary elaboration and runtime execution still
// occur while the inactive malformed dependency remains untouched.
bind sv_bind_owner_inactive_library_target
  sv_bind_owner_inactive_library_probe live_probe();

module sv_bind_owner_inactive_library;
  sv_bind_owner_inactive_library_holder owner();
  sv_bind_owner_inactive_library_target target();

  initial begin
    #1;
    if (sv_bind_owner_inactive_library_counts::hits == 1)
      $display("PASSED");
    else
      $display("FAILED: hits=%0d",
               sv_bind_owner_inactive_library_counts::hits);
  end
endmodule
