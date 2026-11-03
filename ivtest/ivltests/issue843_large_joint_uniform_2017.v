class A;
  rand bit [7:0] v;
endclass

class B extends A;
  rand A left, right;
  constraint heap_order { left.v <= v; right.v > v; }
endclass

module main;
  B h;
  int low, high, bad;

  initial begin
    h = new;
    h.left = new;
    h.right = new;

    repeat (256) begin
      if (!h.randomize()) begin
        bad++;
      end else begin
        if (!(h.left.v <= h.v && h.right.v > h.v))
          bad++;
        if (h.v < 64) low++;
        if (h.v >= 192) high++;
      end
    end

    if (bad || low < 24 || high < 24 || low > 60 || high > 60)
      $fatal(1, "ISSUE843 FAIL low=%0d high=%0d bad=%0d", low, high, bad);
    $display("ISSUE843 large joint uniform PASS");
  end
endmodule
