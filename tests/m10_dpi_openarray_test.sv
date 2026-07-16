// M10: DPI open arrays (35.5.6.1, Annex H.12) — one-dimensional
// dynamic arrays of atom types passed as svOpenArrayHandle. The C
// side queries geometry with svSize/svLow/svHigh and reads/writes
// elements through svGetArrElemPtr1 directly in simulation storage,
// so writes are visible without any copy-back step.
module m10_dpi_openarray_test;

  import "DPI-C" function int c_arr_sum(input int arr[]);
  import "DPI-C" function int c_arr_fill(output int arr[], input int base);
  import "DPI-C" function longint c_arr_sum64(input longint arr[]);
  import "DPI-C" function int c_arr_bytes(inout byte arr[]);
  import "DPI-C" function real c_arr_mean(input real arr[]);
  import "DPI-C" function int c_arr_geom(input shortint arr[]);

  int pass_count = 0;
  int fail_count = 0;

  task check(input string name, input bit ok);
    if (ok) pass_count++;
    else begin
      fail_count++;
      $display("FAIL: %s", name);
    end
  endtask

  int di[];
  longint dl[];
  byte db[];
  real dr[];
  shortint dh[];
  int r;
  longint l;
  real m;
  bit ok;

  initial begin
    // Read access: sum of elements.
    di = new[5];
    foreach (di[i]) di[i] = (i + 1) * 10;
    r = c_arr_sum(di);
    check("sum_int", r == 150);

    // Empty array: svSize 0, no element access.
    di = new[0];
    r = c_arr_sum(di);
    check("sum_empty", r == 0);

    // Write access through the handle (output direction).
    di = new[4];
    r = c_arr_fill(di, 100);
    check("fill_ret", r == 4);
    ok = 1;
    foreach (di[i]) if (di[i] != 100 + i) ok = 0;
    check("fill_elems", ok);

    // 64-bit elements.
    dl = new[3];
    dl[0] = 64'h1_0000_0000;
    dl[1] = 64'h2_0000_0000;
    dl[2] = -64'd12;
    l = c_arr_sum64(dl);
    check("sum64", l == 64'h3_0000_0000 - 64'd12);

    // Byte elements, inout: C doubles each in place and returns count.
    db = new[3];
    db[0] = 10; db[1] = -20; db[2] = 40;
    r = c_arr_bytes(db);
    check("bytes_ret", r == 3);
    check("bytes_elems", db[0] == 20 && db[1] == -40 && db[2] == 80);

    // Real elements.
    dr = new[4];
    dr[0] = 1.0; dr[1] = 2.0; dr[2] = 3.0; dr[3] = 6.0;
    m = c_arr_mean(dr);
    check("real_mean", m == 3.0);

    // Geometry queries on shortint elements: C checks svLow/svHigh/
    // svDimensions/svSizeOfArray consistency and returns 1.
    dh = new[7];
    foreach (dh[i]) dh[i] = i;
    r = c_arr_geom(dh);
    check("geometry", r == 1);

    if (fail_count == 0)
      $display("M10 DPI OPENARRAY TEST: PASS (%0d/%0d)", pass_count, pass_count);
    else
      $display("M10 DPI OPENARRAY TEST: FAIL (%0d passed, %0d failed)",
               pass_count, fail_count);
    $finish(0);
  end
endmodule
