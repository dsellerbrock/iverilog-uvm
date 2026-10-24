module p07_12_4_iterarg_control;
  typedef struct {int index; int v;} idx_type;
  idx_type arr[$], q2[$];
  initial begin
    arr = '{'{index:7, v:10}, '{index:1, v:20}, '{index:9, v:30}};
    q2 = arr.find() with (item.v > 15);
    $display("C1 %0d %0d", q2.size(), q2[0].v);
  end
endmodule
