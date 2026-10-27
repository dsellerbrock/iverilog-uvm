module p10_07_08;
  typedef struct { int a; int b; } P;
  parameter int PA[2] = '{5, 6};
  logic [3:0] a4;
  logic [7:0] a8;
  logic [65:0] w66;
  logic signed [3:0] s4;
  function automatic int sum2(int p[2]); return p[0] + p[1]; endfunction
  function automatic P mk(); return '{a:3, b:4}; endfunction
  P pv;
  initial begin
    s4 = -2;
    a4 = 8'hA5;             $display("T1 %h", a4);        // truncate MSBs -> 5
    a8 = 4'hA;              $display("T2 %h", a8);        // zero-extend -> 0a
    a8 = s4;                $display("T3 %h", a8);        // sign-extend -> fe
    a8 = $unsigned(s4);     $display("T4 %h", a8);        // -> 0e
    a8 = s4 + 4'd1;         $display("T5 %h", a8);        // -> 0f
    a8 = '1; w66 = '1;      $display("T6 %h %0d", a8, $countones(w66)); // ff 66
    $display("C1 %0d %0d", PA[0], PA[1]);                // pattern as parameter value: 5 6
    $display("C2 %0d", sum2('{3, 4}));                   // pattern as subroutine argument: 7
    pv = mk();             $display("C3 %0d %0d", pv.a, pv.b); // pattern as return value: 3 4
  end
endmodule
