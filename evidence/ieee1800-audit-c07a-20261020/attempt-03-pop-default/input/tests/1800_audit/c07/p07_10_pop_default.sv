class K; endclass
module p07_10_pop_default;
  int qi[$]; bit [7:0] qb[$]; logic [7:0] ql[$]; integer qg[$]; real qr[$]; string qs[$]; K qk[$];
  initial begin
    $display("PI %0d %0d %0d", qi.pop_front(), qi.pop_back(), qi[3]);
    $display("PB %0d %0d %0d", qb.pop_front(), qb.pop_back(), qb[3]);
    $display("PL %0d %0d %0d", ql.pop_front(), ql.pop_back(), ql[3]);
    $display("PG %0d %0d %0d", qg.pop_front(), qg.pop_back(), qg[3]);
    $display("PR %0.1f %0.1f %0.1f", qr.pop_front(), qr.pop_back(), qr[3]);
    $display("PS '%s' '%s' '%s'", qs.pop_front(), qs.pop_back(), qs[3]);
    $display("PK %0d %0d %0d", qk.pop_front() == null, qk.pop_back() == null, qk[3] == null);
  end
endmodule
