class C; int id; endclass
module top;
  C arr[4];
  C q[];
  initial begin
    for (int i=0;i<4;i++) begin arr[i]=new; arr[i].id=i; end
    q = arr;                      // legal: fixed array of handles -> dynamic
    $display("q.size=%0d q[2].id=%0d", q.size(), q[2].id);
    $finish(0);
  end
endmodule
