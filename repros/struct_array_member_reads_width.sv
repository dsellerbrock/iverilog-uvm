module top;
  typedef struct { int arr[4]; int tag; } S;
  typedef struct packed { int a; int b; } P;   // packed control
  S s;
  int plain[4];
  initial begin
    s.tag = 7;
    for (int i = 0; i < 4; i++) begin s.arr[i] = 200 + i; plain[i] = 200 + i; end
    $display("struct member elems : %0d %0d %0d %0d (want 200 201 202 203)",
             s.arr[0], s.arr[1], s.arr[2], s.arr[3]);
    $display("the scalar member   : %0d (want 7)", s.tag);
    $display("a plain array       : %0d %0d (want 200 202)", plain[0], plain[2]);
    $finish(0);
  end
endmodule
