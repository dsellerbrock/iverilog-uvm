class U1;
  rand bit [1:0] a[4];
  constraint c { unique {a[0:1]}; }
endclass

module p18_05_5_slice_u1;
  U1 item;
  int ok, bad;
  initial begin
    item = new;
    repeat (50) begin
      if (item.randomize()) begin
        ok++;
        if (item.a[0] == item.a[1]) bad++;
      end
    end
    $display("U1 ok=%0d bad=%0d", ok, bad);
  end
endmodule
