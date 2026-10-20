class disabled_item;
  rand bit [15:0] a, b;
  constraint c { a inside {[1:100]}; b == a + 1; }
endclass

class soft_item;
  rand bit value;
  constraint c { soft value == 1'b1; }
endclass

module main;
  initial begin
    disabled_item item;
    soft_item soft_value;
    int unsigned checksum;
    item = new;
    soft_value = new;
    checksum = 0;
    item.c.constraint_mode(0);
    if (item.c.constraint_mode()) $fatal(1, "constraint did not disable");
    item.srandom(32'h5eed);
    if ($test$plusargs("t4")) begin
      repeat (400) begin
        if (!soft_value.randomize()) $fatal(1, "soft randomize failed");
        $display("soft=%0d", soft_value.value);
      end
    end else begin
      repeat (400) begin
        if (!item.randomize()) $fatal(1, "unconstrained randomize failed");
        $display("%0d,%0d", item.a, item.b);
        checksum = checksum * 33 + item.a * 65537 + item.b;
      end
      $display("checksum=%0d", checksum);
    end
  end
endmodule
