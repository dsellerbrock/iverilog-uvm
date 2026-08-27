// IEEE 1800-2017/2023 23.11: loading a -y target can append another
// compilation-unit bind directive. Automatic root discovery must account for
// that late directive instead of also elaborating its bound module as a root.
package sv_bind_library_late_root_counts;
  int hits;
endpackage

module sv_bind_library_late_root_probe;
  initial sv_bind_library_late_root_counts::hits =
    sv_bind_library_late_root_counts::hits + 1;
endmodule

module sv_bind_library_late_root_trigger_probe;
endmodule

// Resolving this bind loads sv_bind_library_late_root_target from -y. That
// library source contributes the second compilation-unit bind under test.
bind sv_bind_library_late_root_target
  sv_bind_library_late_root_trigger_probe trigger();

module sv_bind_library_late_root;
  sv_bind_library_late_root_target target();

  initial begin
    #1;
    if (sv_bind_library_late_root_counts::hits == 1)
      $display("PASSED");
    else
      $display("FAILED: hits=%0d", sv_bind_library_late_root_counts::hits);
  end
endmodule
