// IEEE 1800-2017/2023 23.11: definition-form bind resolution must load a
// target definition available only through -y before pending binds are
// applied. Runtime observation proves the bind reached the library instance.
package sv_bind_library_target_counts;
  int hits;
endpackage

module sv_bind_library_target_probe;
  initial sv_bind_library_target_counts::hits =
    sv_bind_library_target_counts::hits + 1;
endmodule

bind sv_bind_library_target_leaf sv_bind_library_target_probe p();

module sv_bind_library_target;
  sv_bind_library_target_leaf target();

  initial begin
    #1;
    if (sv_bind_library_target_counts::hits == 1)
      $display("PASSED");
    else
      $display("FAILED: hits=%0d", sv_bind_library_target_counts::hits);
  end
endmodule
