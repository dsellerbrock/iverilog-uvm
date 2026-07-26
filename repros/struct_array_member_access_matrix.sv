module top;
  typedef struct { int arr[4]; } S;
  S s;
  int fails = 0;
  function automatic int sum_open(input int a[]);
    int t = 0;
    foreach (a[i]) t += a[i];
    return t;
  endfunction
  initial begin
    for (int i = 0; i < 4; i++) s.arr[i] = 200 + i;
    // direct reads
    if (s.arr[2] !== 202) begin fails++; $display("FAILED direct elem read: %0d", s.arr[2]); end
    if ($size(s.arr) !== 4) begin fails++; $display("FAILED $size: %0d", $size(s.arr)); end
    // foreach over the member
    begin
      int t = 0;
      foreach (s.arr[i]) t += s.arr[i];
      if (t !== 806) begin fails++; $display("FAILED foreach over the member: %0d want 806", t); end
    end
    // passed to a SystemVerilog subroutine taking an open array
    if (sum_open(s.arr) !== 806) begin fails++; $display("FAILED SV open-array arg: %0d want 806", sum_open(s.arr)); end
    if (fails == 0) $display("PASSED");
    $finish(0);
  end
endmodule
