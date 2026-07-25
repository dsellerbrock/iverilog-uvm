// Does an object-array element read honour its index?
class C; int id; function new(int i); id=i; endfunction endclass
module top;
  C arr[4];
  C q[$];
  initial begin
    int ok = 1;
    for (int i=0;i<4;i++) arr[i] = new(100+i);
    // constant index
    if (arr[2].id != 102) begin $display("FAIL const idx arr[2].id=%0d (want 102)", arr[2].id); ok=0; end
    // run-time variable index
    for (int i=0;i<4;i++) begin
      automatic int want = 100+i;
      if (arr[i].id != want) begin $display("FAIL var idx arr[%0d].id=%0d (want %0d)", i, arr[i].id, want); ok=0; end
    end
    // expression index
    for (int i=0;i<3;i++)
      if (arr[i+1].id != 101+i) begin $display("FAIL expr idx arr[%0d+1].id=%0d", i, arr[i+1].id); ok=0; end
    // queue of objects
    for (int i=0;i<4;i++) begin automatic C t = new(200+i); q.push_back(t); end
    for (int i=0;i<4;i++)
      if (q[i].id != 200+i) begin $display("FAIL queue idx q[%0d].id=%0d", i, q[i].id); ok=0; end
    if (ok) $display("PASS objidx");
    $finish(0);
  end
endmodule
