class C; int id; endclass
module top;
  C arr[4];
  C h;
  initial begin
    for (int i=0;i<4;i++) begin arr[i]=new; arr[i].id=i; end
    h = arr;                       // whole array to a handle: illegal
    $finish(0);
  end
endmodule
