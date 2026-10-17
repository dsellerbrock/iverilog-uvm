// IEEE 1800-2017/2023 7.4, 7.8: module-scope associative entries may
// contain fixed arrays of class handles.
class entry;
  int value;
  function new(int value); this.value = value; endfunction
endclass

module top;
  entry src[int][8:9];
  entry saved;

  initial begin
    saved = new(17);
    if (src.exists(4) || src[4][8] != null || src.exists(4))
      $fatal(1, "absent associative entry read allocated storage");
    src[4][8] = saved;
    if (!src.exists(4) || src[4][8] != saved || src[4][9] != null)
      $fatal(1, "module associative fixed-array handle write/read");
    saved.value = 18;
    if (src[4][8] != saved)
      $fatal(1, "module associative fixed-array handle identity");
    $display("PASSED");
  end
endmodule
