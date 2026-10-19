module sparse_mul;
  reg [1023:0] a, b, p;
  reg [64:0] c, d, q;

  initial begin
    a = 1024'd7;
    b = 1024'h1021;
    p = a * b;
    $display("sparse_low=%h", p);

    a = 1024'b1 << 700;
    b = 1024'h123456789abcdef;
    p = a * b;
    $display("sparse_high=%h", p);

    a = {1024{1'b1}};
    b = {1024{1'b1}};
    p = a * b;
    $display("dense_truncated=%h", p);

    a = 0;
    b = {1024{1'b1}};
    p = a * b;
    $display("zero=%h", p);

    a = 1;
    a[900] = 1'bx;
    b = 3;
    p = a * b;
    $display("xz=%h", p);

    c = 65'h10000000000000000;
    d = 65'd3;
    q = c * d;
    $display("65_bit=%h", q);

    a = 1024'hfedcba9876543210;
    a = a * a;
    $display("self_multiply=%h", a);

    a = 0;
    b = 0;
    for (integer i = 0; i < 32; i = i + 1) begin
      a[i*32 +: 32] = (i + 1) * 32'h9e3779b9;
      b[i*32 +: 32] = (i + 3) * 32'h7f4a7c15;
    end
    p = a * b;
    $display("dense_words=%h", p);
    $finish;
  end
endmodule
