module test;
  class ovr;
    int x;

    function new(int v);
      x = v;
    endfunction
  endclass

  initial begin
    ovr a;
    ovr b;
    ovr q1[$], q2[$], q[$];
    int i;

    a = new(11);
    b = new(22);
    q1.push_back(a);
    q2.push_back(b);
    q = {q1, q2};

    if (q.size() != 2) begin
      $display("FAILED: size=%0d", q.size());
      $finish(1);
    end

    foreach (q[i]) begin
      if (q[i] == null) begin
        $display("FAILED: q[%0d] null", i);
        $finish(1);
      end

      if (q[i].x !== (i == 0 ? 11 : 22)) begin
        $display("FAILED: q[%0d].x=%0d", i, q[i].x);
        $finish(1);
      end
    end

    $display("PASSED");
  end
endmodule
