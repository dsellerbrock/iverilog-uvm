// Class properties that are unpacked arrays of `real` or `string`.
//
// These used to silently miscompile: the real/string property store and
// load opcodes carried no element index, so every element resolved to the
// same slot — element-wise writes clobbered one another (all elements read
// back as the last value written) and whole-array assignment patterns
// aborted (real) or produced empty strings. The cobject real/string
// property storage is now array-capable (property_real/property_string
// carry an array size), and new indexed opcodes %store/prop/{r,str}/i and
// %prop/{r,str}/i select the element.
//
// Covers element-wise write, whole-array pattern write, variable-index
// read/write, scalar (non-array) properties as a regression, and a
// shallow copy. Prints PASSED only if every access matches.

module sv_class_prop_real_string_array;

  class C;
    real   rs;         // scalar real (regression)
    string ss;         // scalar string (regression)
    real   ra [3];     // unpacked real array
    string sa [3];     // unpacked string array

    function void fill_ew();
      rs = 9.5; ss = "scalar";
      ra[0] = 1.5; ra[1] = 2.5; ra[2] = 3.5;
      sa[0] = "aa"; sa[1] = "bb"; sa[2] = "cc";
    endfunction

    function void fill_pat();
      ra = '{4.5, 5.5, 6.5};
      sa = '{"xx", "yy", "zz"};
    endfunction
  endclass

  int errors = 0;

  task automatic chk_r(real got, real exp, string what);
    if (got != exp) begin $display("FAIL %s got=%0.2f exp=%0.2f", what, got, exp); errors++; end
  endtask
  task automatic chk_s(string got, string exp, string what);
    if (got != exp) begin $display("FAIL %s got=%s exp=%s", what, got, exp); errors++; end
  endtask

  initial begin
    C c = new;

    // element-wise writes
    c.fill_ew();
    chk_r(c.rs, 9.5, "rs");
    chk_s(c.ss, "scalar", "ss");
    chk_r(c.ra[0], 1.5, "ra0 ew"); chk_r(c.ra[1], 2.5, "ra1 ew"); chk_r(c.ra[2], 3.5, "ra2 ew");
    chk_s(c.sa[0], "aa", "sa0 ew"); chk_s(c.sa[1], "bb", "sa1 ew"); chk_s(c.sa[2], "cc", "sa2 ew");

    // whole-array assignment patterns
    c.fill_pat();
    chk_r(c.ra[0], 4.5, "ra0 pat"); chk_r(c.ra[1], 5.5, "ra1 pat"); chk_r(c.ra[2], 6.5, "ra2 pat");
    chk_s(c.sa[0], "xx", "sa0 pat"); chk_s(c.sa[1], "yy", "sa1 pat"); chk_s(c.sa[2], "zz", "sa2 pat");

    // variable-index read and write
    for (int i = 0; i < 3; i++) c.ra[i] = i * 10.0 + 0.25;
    for (int i = 0; i < 3; i++) chk_r(c.ra[i], i * 10.0 + 0.25, "ra var");

    // shallow copy preserves per-element array contents. Use the
    // statement form (`d = new c`); the declaration-initializer form
    // `C d = new c;` has a separate, pre-existing copy-constructor bug.
    begin
      C d;
      d = new c;
      chk_r(d.ra[0], 0.25, "copy ra0"); chk_r(d.ra[1], 10.25, "copy ra1"); chk_r(d.ra[2], 20.25, "copy ra2");
      chk_s(d.sa[0], "xx", "copy sa0"); chk_s(d.sa[2], "zz", "copy sa2");
      chk_r(d.rs, 9.5, "copy rs");
    end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish(0);
  end

endmodule
