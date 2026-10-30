module test;
  int ov[0:3];
  real rs[0:2];

  initial begin
    foreach (ov[i]) ov[i] = i + 1;
    ov[1:2] = '{ov[2], ov[1]};
    $display("%0d %0d %0d %0d", ov[0], ov[1], ov[2], ov[3]);

    rs = '{0.5, 1.5, 2.5};
    rs[1:2] = '{rs[2], rs[1]};
    $display("%.1f %.1f %.1f", rs[0], rs[1], rs[2]);

    ov = '{ov[2], ov[1], ov[0], ov[3]};
    $display("%0d %0d %0d %0d", ov[0], ov[1], ov[2], ov[3]);
  end
endmodule
