// IEEE 1800-2017 7.6: a fixed-size unpacked array and the dynamic array
// or queue assigned to it must have the same number of elements.
//
// A dynamic source has no size until it runs, so this is necessarily a
// run-time check -- it lives in %store/arr/dar, the one instruction
// every container -> fixed-array copy goes through. It reports and
// leaves the destination alone rather than copying the elements that
// happen to fit, so a wrong-sized copy cannot half-update an array and
// then be read as if it were whole.
//
// The companion positive matrix is sv_whole_aggregate_value_copy.

module main;

  int fa[3];
  int da[];
  int qu[$];

  initial begin
    fa = '{1, 2, 3};

    // too many
    da = new[5];
    da[0] = 9; da[4] = 9;
    fa = da;
    $display("after the oversized copy: %0d %0d %0d", fa[0], fa[1], fa[2]);

    // too few
    qu = '{7};
    fa = qu;
    $display("after the undersized copy: %0d %0d %0d", fa[0], fa[1], fa[2]);

    // an empty container is still a mismatch, not a clear
    da = new[0];
    fa = da;
    $display("after the empty copy: %0d %0d %0d", fa[0], fa[1], fa[2]);

    // and the matching size still copies
    da = new[3];
    da[0] = 40; da[1] = 50; da[2] = 60;
    fa = da;
    $display("after the matching copy: %0d %0d %0d", fa[0], fa[1], fa[2]);

    $finish(0);
  end

endmodule
