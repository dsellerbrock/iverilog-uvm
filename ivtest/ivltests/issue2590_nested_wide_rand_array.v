module main;
  class leaf;
    rand bit [127:0] v[2];
    rand logic signed [95:0] s[1];
  endclass

  class item;
    rand leaf l;
    constraint c { l.v[0] == l.v[1] + 128'd1; l.s[0] == -96'sd3; }
    function new; l = new; endfunction
  endclass

  item x = new;
  int bad;

  initial begin
    bad = 0;
    repeat (8) begin
      if (!x.randomize()
          || x.l.v[0] != x.l.v[1] + 128'd1
          || x.l.s[0] != -96'sd3)
        bad++;
    end
    x.l.v[0] = {64'hFEED, 64'h10};
    x.l.v[1] = {64'hFEED, 64'hF};
    x.l.v.rand_mode(0);
    repeat (4) begin
      if (!x.randomize()
          || x.l.v[0] != {64'hFEED, 64'h10}
          || x.l.v[1] != {64'hFEED, 64'hF}
          || x.l.s[0] != -96'sd3)
        bad++;
    end
    $display("%0d", bad);
    $finish;
  end
endmodule
