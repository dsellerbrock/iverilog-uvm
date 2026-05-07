// G10: sum, product, min, max on dynamic arrays and queues
// Note: .and()/.or()/.xor() are reserved keywords; tested separately via elab path
module g10_darray_reduction_test;
  initial begin
    int da[];
    int q[$];
    int s, p;
    int mn[], mx[];

    da = '{1, 2, 3, 4};

    // sum: 1+2+3+4 = 10
    s = da.sum();
    if (s !== 10) begin
      $display("FAIL: da.sum()=%0d (exp 10)", s);
      $finish;
    end

    // product: 1*2*3*4 = 24
    p = da.product();
    if (p !== 24) begin
      $display("FAIL: da.product()=%0d (exp 24)", p);
      $finish;
    end

    // min: returns array with element 1
    mn = da.min();
    if (mn.size() !== 1 || mn[0] !== 1) begin
      $display("FAIL: da.min() size=%0d val=%0d (exp 1)", mn.size(), mn.size() ? mn[0] : -1);
      $finish;
    end

    // max: returns array with element 4
    mx = da.max();
    if (mx.size() !== 1 || mx[0] !== 4) begin
      $display("FAIL: da.max() size=%0d val=%0d (exp 4)", mx.size(), mx.size() ? mx[0] : -1);
      $finish;
    end

    // Queue reductions
    q = {5, 3, 7, 1};
    s = q.sum();
    if (s !== 16) begin
      $display("FAIL: q.sum()=%0d (exp 16)", s);
      $finish;
    end

    mn = q.min();
    if (mn.size() !== 1 || mn[0] !== 1) begin
      $display("FAIL: q.min() size=%0d val=%0d (exp 1)", mn.size(), mn.size() ? mn[0] : -1);
      $finish;
    end

    mx = q.max();
    if (mx.size() !== 1 || mx[0] !== 7) begin
      $display("FAIL: q.max() size=%0d val=%0d (exp 7)", mx.size(), mx.size() ? mx[0] : -1);
      $finish;
    end

    $display("PASS");
  end
endmodule
