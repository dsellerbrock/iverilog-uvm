// IEEE 1800-2017/2023 12.7.3: foreach traverses a whole array target
// whose outer ranks are fixed and whose leaf is runtime-sized.  Distinct
// fixed slots have ragged lengths and keys so a lost fixed selector fails.
class mixed_cfg;
  int q[1:0][3:2][$];
  int d[1:0][3:2][];
  int a[1:0][3:2][string];
  int q_seen, d_seen, a_seen;

  function void run();
    foreach (q[i,j]) begin
      for (int k = 0; k < i+j-1; ++k)
        q[i][j].push_back(100*i+10*j+k);
      d[i][j] = new[i+j-1];
      for (int k = 0; k < i+j-1; ++k)
        d[i][j][k] = 100*i+10*j+k;
      a[i][j][$sformatf("%0d:%0d", i, j)] = 100*i+10*j;
    end
    a[1][3]["extra"] = 113;

    foreach (q[i,j,k]) begin
      if (q[i][j][k] != 100*i+10*j+k)
        $fatal(1, "class queue selected wrong fixed slot");
      q_seen++;
    end
    foreach (d[i,j,k]) begin
      if (d[i][j][k] != 100*i+10*j+k)
        $fatal(1, "class dynamic array selected wrong fixed slot");
      d_seen++;
    end
    foreach (a[i,j,k]) begin
      if (k == $sformatf("%0d:%0d", i, j)) begin
        if (a[i][j][k] != 100*i+10*j)
          $fatal(1, "class associative array selected wrong fixed slot");
      end else if (k == "extra" && i == 1 && j == 3) begin
        if (a[i][j][k] != 113) $fatal(1, "class extra key value");
      end else $fatal(1, "class key escaped its fixed slot: %s", k);
      a_seen++;
    end
    if (q_seen != 8 || d_seen != 8 || a_seen != 5)
      $fatal(1, "class visits q=%0d d=%0d a=%0d", q_seen, d_seen, a_seen);
  endfunction
endclass

module top;
  int q[1:0][3:2][$];
  int d[1:0][3:2][];
  int a[1:0][3:2][string];
  int q_seen, d_seen, a_seen, nested_seen;
  mixed_cfg c;

  initial begin
    c = new;
    c.run();
    foreach (c.q[i,j,k]) begin
      if (c.q[i][j][k] != 100*i+10*j+k)
        $fatal(1, "nested class target selected wrong fixed slot");
      nested_seen++;
    end
    if (nested_seen != 8) $fatal(1, "nested class visits=%0d", nested_seen);

    foreach (q[i,j]) begin
      for (int k = 0; k < i+j-1; ++k)
        q[i][j].push_back(100*i+10*j+k);
      d[i][j] = new[i+j-1];
      for (int k = 0; k < i+j-1; ++k)
        d[i][j][k] = 100*i+10*j+k;
      a[i][j][$sformatf("%0d:%0d", i, j)] = 100*i+10*j;
    end
    a[1][3]["extra"] = 113;

    foreach (q[i,j,k]) begin
      if (q[i][j][k] != 100*i+10*j+k)
        $fatal(1, "signal queue selected wrong fixed slot");
      case (q_seen)
        0, 1, 2: if (i != 1 || j != 3 || k != q_seen)
                   $fatal(1, "signal queue outer order");
        3, 4:    if (i != 1 || j != 2 || k != q_seen-3)
                   $fatal(1, "signal queue outer order");
        5, 6:    if (i != 0 || j != 3 || k != q_seen-5)
                   $fatal(1, "signal queue outer order");
        7:       if (i != 0 || j != 2 || k != 0)
                   $fatal(1, "signal queue outer order");
        default:  $fatal(1, "signal queue excess visit");
      endcase
      q_seen++;
    end
    foreach (d[i,j,k]) begin
      if (d[i][j][k] != 100*i+10*j+k)
        $fatal(1, "signal dynamic array selected wrong fixed slot");
      d_seen++;
    end
    foreach (a[i,j,k]) begin
      if (k == $sformatf("%0d:%0d", i, j)) begin
        if (a[i][j][k] != 100*i+10*j)
          $fatal(1, "signal associative array selected wrong fixed slot");
      end else if (k == "extra" && i == 1 && j == 3) begin
        if (a[i][j][k] != 113) $fatal(1, "signal extra key value");
      end else $fatal(1, "signal key escaped its fixed slot: %s", k);
      a_seen++;
    end
    if (q_seen != 8 || d_seen != 8 || a_seen != 5)
      $fatal(1, "signal visits q=%0d d=%0d a=%0d", q_seen, d_seen, a_seen);
    $display("PASSED");
  end
endmodule
