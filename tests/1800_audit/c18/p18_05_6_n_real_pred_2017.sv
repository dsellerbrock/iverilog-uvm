module p18_05_6_n_real_pred_2017;
  class Q;
    real w;
    rand bit b;
    constraint k { w -> (b == 1); }
  endclass
  Q q;
  initial begin
    q = new;
    q.w = 0.5;
    void'(q.randomize());
    $display("Q b=%0d", q.b);
  end
endmodule
