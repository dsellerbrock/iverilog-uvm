// M2: whole unpacked-array assignment (IEEE 1800-2017 7.6) between all
// combinations of static-array signals and class properties. Reduced
// from UVM uvm_field_sarray_int COPY failures (gap audit G25).
module m2_uarray_assign_test;
  class C;
    int arr[4];
    function void copy_from(C rhs);
      arr = rhs.arr;   // property = property (the UVM field-macro shape)
    endfunction
  endclass

  int x[4], y[4];
  byte bsrc[6];
  byte bdst[6];

  initial begin
    C a = new, b = new;
    int lv[4];
    int errors = 0;

    // signal = signal
    foreach (y[i]) y[i] = (i + 1) * 5;
    x = y;
    if (x[0] !== 5 || x[3] !== 20) begin
      $display("FAIL: sig=sig x[0]=%0d x[3]=%0d", x[0], x[3]);
      errors++;
    end

    // property = property (inside class method)
    foreach (a.arr[i]) a.arr[i] = 10 * (i + 1);
    b.copy_from(a);
    if (b.arr[0] !== 10 || b.arr[3] !== 40) begin
      $display("FAIL: prop=prop b.arr[0]=%0d b.arr[3]=%0d", b.arr[0], b.arr[3]);
      errors++;
    end

    // local = property
    lv = a.arr;
    if (lv[2] !== 30) begin
      $display("FAIL: local=prop lv[2]=%0d", lv[2]);
      errors++;
    end

    // property = local
    lv[2] = 77;
    b.arr = lv;
    if (b.arr[2] !== 77) begin
      $display("FAIL: prop=local b.arr[2]=%0d", b.arr[2]);
      errors++;
    end

    // source values must be copied, not aliased
    y[0] = 999;
    if (x[0] !== 5) begin
      $display("FAIL: aliasing detected, x[0]=%0d", x[0]);
      errors++;
    end

    // byte-element arrays (different element width than int)
    foreach (bsrc[i]) bsrc[i] = 8'h20 + i;
    bdst = bsrc;
    if (bdst[5] !== 8'h25) begin
      $display("FAIL: byte array bdst[5]=%02h", bdst[5]);
      errors++;
    end

    if (errors == 0) $display("PASS");
    $finish;
  end
endmodule
