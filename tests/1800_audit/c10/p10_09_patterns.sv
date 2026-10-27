module p10_09_patterns;
  typedef struct { int a; byte b; int c; real r; } S;
  S s; int arr[0:3]; int a2[2][3]; logic [7:0] pk[4];
  initial begin
    s = '{a:1, b:2, c:3, r:4.5};               $display("P1 %0d %0d %0d %0.1f", s.a, s.b, s.c, s.r);
    s = '{int:7, default:0};                    $display("P2 %0d %0d %0d %0.1f", s.a, s.b, s.c, s.r);
    s = '{c:9, int:7, default:1};               $display("P3 %0d %0d %0d %0.1f", s.a, s.b, s.c, s.r);
    s = '{1, 2, 3, 0.5};                        $display("P4 %0d %0d %0d %0.1f", s.a, s.b, s.c, s.r);
    arr = '{1:5, default:2};                    $display("A1 %0d %0d %0d %0d", arr[0], arr[1], arr[2], arr[3]);
    arr = '{4{3}};                              $display("A2 %0d %0d", arr[0], arr[3]);
    a2 = '{'{1,2,3}, '{default:9}};             $display("A3 %0d %0d %0d", a2[0][2], a2[1][0], a2[1][2]);
    pk = '{default:8'hA5};                      $display("A4 %h %h", pk[0], pk[3]);
    arr = '{2{1,2}};                             $display("A5 %0d %0d %0d %0d", arr[0], arr[1], arr[2], arr[3]);
  end
endmodule
