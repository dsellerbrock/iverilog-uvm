// Existing state selectors and outer iterators must retain their identities.
class selected_declared;
  int selected = 1;
  rand int a[2][3];
  constraint c {
    foreach (a[selected][j]) a[1][j] == 10 + j;
    foreach (a[i]) {
      foreach (a[i][j]) if (i == 0) a[i][j] == j;
    }
  }
endclass
module main;
  selected_declared obj;
  initial begin
    obj = new;
    repeat (3) begin
      if (!obj.randomize()) $fatal(1, "randomize");
      foreach (obj.a[i,j])
        if (obj.a[i][j] != 10 * i + j) $fatal(1, "wrong index/value");
    end
    $display("PASSED");
    $finish;
  end
endmodule
