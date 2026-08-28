// IEEE 1800-2017/2023 23.11 / Syntax 23-9: selected-instance bind
// resolution must load a -y-only container definition to traverse the
// owner.child path. Runtime observation proves the resolved child was bound.
package sv_bind_library_path_counts;
  int hits;
endpackage

module sv_bind_library_path_probe;
  initial sv_bind_library_path_counts::hits =
    sv_bind_library_path_counts::hits + 1;
endmodule

module sv_bind_library_path;
  sv_bind_library_path_container owner();

  initial begin
    #1;
    if (sv_bind_library_path_counts::hits == 1)
      $display("PASSED");
    else
      $display("FAILED: hits=%0d", sv_bind_library_path_counts::hits);
  end
endmodule

bind sv_bind_library_path.owner.child sv_bind_library_path_probe p();
