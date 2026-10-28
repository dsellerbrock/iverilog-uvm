module t;
  typedef struct packed { logic [3:0] a; logic [7:0] b; } P;
  typedef struct { P value; } PO;
  PO p;

  initial begin
    p = '{value:'{a:4'd5, b:8'd5}};
    $display("packed %b", p.value);
    $display("fields %0d %0d", p.value.a, p.value.b);
  end
endmodule
