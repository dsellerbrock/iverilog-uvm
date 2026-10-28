module t;
  typedef struct packed { logic [3:0] a; logic [7:0] b; } P;
  typedef struct { P value; } PO;
  PO p1, p2, p3, p4;
  P p5;
  initial begin
    p1 = '{value:'{a:4'd5, b:8'd5}};
    p2 = '{value:'{default:5}};
    p3 = '{'{4'd5, 8'd5}};
    p4 = '{default:5};
    p5 = '{default:5};
    $display("p1 packed %b", p1.value);
    $display("p1 fields %0d %0d", p1.value.a, p1.value.b);
    $display("p2 packed %b", p2.value);
    $display("p2 fields %0d %0d", p2.value.a, p2.value.b);
    $display("p3 packed %b", p3.value);
    $display("p3 fields %0d %0d", p3.value.a, p3.value.b);
    $display("p4 packed %b", p4.value);
    $display("p4 fields %0d %0d", p4.value.a, p4.value.b);
    $display("p5 packed %b", p5);
    $display("p5 fields %0d %0d", p5.a, p5.b);
  end
endmodule
