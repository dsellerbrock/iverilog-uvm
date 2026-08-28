// IEEE 1800-2017/2023 17/23.11: a checker declaration is instantiable and
// bindable but is not an automatic design root. This regression deliberately
// runs without -s; a checker-root bug executes the variable initializer and
// makes the package counter nonzero.
package sv_bind_checker_root_selection_counts;
  int roots;

  function int mark_root();
    roots = roots + 1;
    mark_root = 0;
  endfunction
endpackage

checker sv_bind_checker_root_selection_orphan;
  int marker = sv_bind_checker_root_selection_counts::mark_root();
endchecker

module sv_bind_checker_root_selection;
  initial begin
    #0;
    if (sv_bind_checker_root_selection_counts::roots == 0)
      $display("PASSED");
    else
      $display("FAILED: checker roots=%0d",
               sv_bind_checker_root_selection_counts::roots);
  end
endmodule
