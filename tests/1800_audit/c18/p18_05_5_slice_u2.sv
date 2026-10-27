class U2;
  rand bit [1:0] a[4];
  constraint c { unique {a[1:0]}; }
endclass

module p18_05_5_slice_u2;
  U2 item;
  int ok, bad;
  initial begin
    item = new;
    repeat (50) begin
      if (item.randomize()) begin
        ok++;
        if (item.a[1] == item.a[0]) bad++;
      end
    end
    $display("U2 ok=%0d bad=%0d", ok, bad);
  end
endmodule
