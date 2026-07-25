class C; int id; endclass
function automatic int takes(C x); return x.id; endfunction
module top;
  C arr[4];
  initial begin
    for (int i=0;i<4;i++) begin arr[i]=new; arr[i].id=i; end
    $display("%0d", takes(arr));   // whole array as an object argument
    $finish(0);
  end
endmodule
