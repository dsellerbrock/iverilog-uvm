// IEEE 1800-2017/2023 7.10.3 and 13.5.2: a ref queue formal aliases its
// actual queue. A selected element passed onward by ref must follow the
// element when push_front shifts its index.
module main;
  int q[$];

  task automatic rd(ref int value);
    #2 $display("rd %0d", value);
  endtask

  task automatic rd_const(const ref int value);
    #2 $display("rd const %0d", value);
  endtask

  task automatic fwd(ref int value[$]);
    rd(value[1]);
  endtask

  task automatic fwd_const(const ref int value[$]);
    rd_const(value[1]);
  endtask

  initial begin
    q = '{1, 2, 3};
    fork fwd(q); join_none
    #1 begin
      q.push_front(0);
      q[2] = 22;
    end
    #2;
    q = '{4, 5, 6};
    fork fwd_const(q); join_none
    #1 begin
      q.push_front(0);
      q[2] = 55;
    end
  end
endmodule
