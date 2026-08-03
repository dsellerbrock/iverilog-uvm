// IEEE 1800-2017 7.4.6, 13.5.1/13.5.2 and 35.5.6.1:
// a fixed unpacked-array slice is an aggregate subroutine actual. Copy-in
// and copy-out operate element-for-element, and an open formal observes the
// slice's declared bounds (including a descending range).
module m10_subroutine_array_slice_test;
  class SliceHolder;
    int errors;
    int prop_src[0:7];
    int prop_out[0:7];
    int prop_io[0:7];

    task automatic fixed_check(input int a[4]);
      if (a[0] != 401 || a[3] != 404) errors++;
    endtask

    task automatic fixed_fill(output int a[4]);
      for (int i = 0; i < 4; i++) a[i] = 500 + i;
    endtask

    task automatic open_bump(inout int a[]);
      if ($left(a) != 3 || $right(a) != 6) errors++;
      for (int i = $low(a); i <= $high(a); i++) a[i] += 40;
    endtask

    task run();
      foreach (prop_src[i]) prop_src[i] = 400 + i;
      foreach (prop_out[i]) prop_out[i] = -1;
      foreach (prop_io[i]) prop_io[i] = 600 + i;
      fixed_check(prop_src[1:4]);
      fixed_fill(prop_out[2:5]);
      open_bump(prop_io[3:6]);
      for (int i = 0; i < 4; i++) begin
        if (prop_out[2+i] != 500+i) errors++;
        if (prop_io[3+i] != 643+i) errors++;
      end
    endtask
  endclass

  int errors;
  int src[0:9];
  int fixed_out[0:9];
  int fixed_io[0:9];
  int fixed_ref[0:9];
  int open_out[0:9];
  int open_io[0:9];
  int desc[10:3];
  SliceHolder holder;

  task automatic fixed_ports(
      input  int a[0:3],
      output int b[4],
      inout  int c[0:3],
      ref    int r[0:3]);
    if (a[0] != 102 || a[3] != 105) errors++;
    for (int i = 0; i < 4; i++) begin
      b[i] = 200 + i;
      c[i] += 10;
      r[i] += 20;
    end
  endtask

  task automatic open_ports(
      input  int a[],
      output int b[],
      inout  int c[]);
    if (a.size() != 4 || b.size() != 4 || c.size() != 4) errors++;
    if ($left(a) != 1 || $right(a) != 4) errors++;
    if (a[1] != 101 || a[4] != 104) errors++;
    for (int i = $low(a); i <= $high(a); i++) begin
      b[i] = 300 + i;
      c[i] += 30;
    end
  endtask

  task automatic descending_open(input int a[]);
    if (a.size() != 4 || $left(a) != 8 || $right(a) != 5
        || $increment(a) != 1) begin
      $display("descending bounds size=%0d left=%0d right=%0d increment=%0d",
               a.size(), $left(a), $right(a), $increment(a));
      errors++;
    end
    if (a[5] != 1005 || a[8] != 1008) errors++;
  endtask

  initial begin
    foreach (src[i]) src[i] = 100 + i;
    foreach (fixed_out[i]) fixed_out[i] = -1;
    foreach (fixed_io[i]) fixed_io[i] = 1000 + i;
    foreach (fixed_ref[i]) fixed_ref[i] = 2000 + i;
    foreach (open_out[i]) open_out[i] = -1;
    foreach (open_io[i]) open_io[i] = 3000 + i;
    foreach (desc[i]) desc[i] = 1000 + i;

    fixed_ports(src[2:5], fixed_out[3:6],
                fixed_io[4:7], fixed_ref[5:8]);
    for (int i = 0; i < 4; i++) begin
      if (fixed_out[3+i] != 200+i) errors++;
      if (fixed_io[4+i] != 1014+i) errors++;
      if (fixed_ref[5+i] != 2025+i) errors++;
    end

    open_ports(src[1:4], open_out[1:4], open_io[1:4]);
    for (int i = 0; i < 4; i++) begin
      if (open_out[1+i] != 301+i) errors++;
      if (open_io[1+i] != 3031+i) errors++;
    end

    descending_open(desc[8:5]);

    holder = new;
    holder.run();
    errors += holder.errors;

    if (errors == 0)
      $display("PASS m10_subroutine_array_slice_test");
    else begin
      $display("FAIL m10_subroutine_array_slice_test errors=%0d", errors);
      $display("fixed_out=%p fixed_io=%p fixed_ref=%p", fixed_out, fixed_io, fixed_ref);
      $display("open_out=%p open_io=%p", open_out, open_io);
    end
    $finish;
  end
endmodule
