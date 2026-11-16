// IEEE 1800-2023 37.16: every declared net is an object of its module,
// reachable by name and through vpi_iterate(vpiNet), even when nothing
// drives or reads it, and it reports its declared vpiNetType.
module top;
  wire w;
  wand wa;
  wor wo;
  tri0 t0;
  tri1 t1;
  uwire uw;
  initial #1 begin
    $probe;
    $display("DONE");
  end
endmodule
