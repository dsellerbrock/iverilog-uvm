package sv_assoc_queue_foreach1_pkg;
  typedef int q_t[$];
endpackage

module test;
  sv_assoc_queue_foreach1_pkg::q_t q_by_key[int];
  int outer;
  int inner;
  int sum;
  int count;

  initial begin
    q_by_key[7].push_back(10);
    q_by_key[7].push_back(20);
    q_by_key[3].push_back(30);

    foreach (q_by_key[outer, inner]) begin
      count += 1;
      sum += q_by_key[outer][inner];
    end

    if (count !== 3) begin
      $display("FAIL: count=%0d", count);
      $finish(1);
    end

    if (sum !== 60) begin
      $display("FAIL: sum=%0d", sum);
      $finish(1);
    end

    $display("PASSED");
  end
endmodule
