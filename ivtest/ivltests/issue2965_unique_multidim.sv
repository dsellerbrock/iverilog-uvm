class unique_grid;
  rand bit [1:0] a[2][2];
  constraint c { unique {a}; }
endclass

class unique_mixed;
  rand bit [2:0] a[1:0][-1:0][2:2];
  rand bit [2:0] extra;
  constraint c { unique {a, extra}; }
endclass

class impossible_grid;
  rand bit a[2][2];
  constraint c { unique {a}; }
endclass

module issue2965_unique_multidim;
  unique_grid grid;
  unique_mixed mixed;
  impossible_grid impossible;
  bit [7:0] seen;
  initial begin
    grid = new;
    mixed = new;
    impossible = new;
    repeat (4) begin
      seen = 0;
      if (!grid.randomize()) $fatal(1, "grid randomize failed");
      foreach (grid.a[i,j]) begin
        if (seen[grid.a[i][j]]) $fatal(1, "duplicate grid leaf");
        seen[grid.a[i][j]] = 1;
      end
      if (seen[3:0] != 4'b1111) $fatal(1, "missing grid value");
      seen = 0;
      if (!mixed.randomize()) $fatal(1, "mixed randomize failed");
      foreach (mixed.a[i,j,k]) begin
        if (seen[mixed.a[i][j][k]]) $fatal(1, "duplicate mixed leaf");
        seen[mixed.a[i][j][k]] = 1;
      end
      if (seen[mixed.extra]) $fatal(1, "duplicate scalar");
    end
    if (impossible.randomize()) $fatal(1, "impossible grid succeeded");
    $display("PASS multidimensional unique leaves");
  end
endmodule
