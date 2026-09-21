module top;
  class leaf_t; logic [1:0] bits; endclass
  class cfg_t; leaf_t owner[2]; int pick; int bitpick; endclass
  cfg_t cfg = new;
  int wake0, wake1;
  task automatic waiter(input int owner_i, input int bit_i);
    @(cfg.owner[owner_i].bits[bit_i]);
    if (owner_i == 0) wake0++; else wake1++;
  endtask
  initial begin
    cfg.owner[0] = new; cfg.owner[1] = new;
    cfg.owner[0].bits = 0; cfg.owner[1].bits = 0;
    fork waiter(0, 0); waiter(1, 1); join_none
    #1 begin
      cfg.owner[0].bits[0] = 1;
      #0;
      if (wake0 != 1 || wake1 != 0) $fatal(1, "automatic owner capture aliased: %0d/%0d", wake0, wake1);
      cfg.owner[1].bits[1] = 1;
    end
    #1 begin
      if (wake0 != 1 || wake1 != 1) $fatal(1, "nested owner capture lost: %0d/%0d", wake0, wake1);
      $display("PASS nested-owner-concurrent"); $finish(0);
    end
  end
endmodule
