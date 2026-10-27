module p07_12_4_iterarg;
  typedef struct {int index; int v;} idx_type;
  idx_type arr[$], q2[$];
  initial begin
    arr = '{'{index:7, v:10}, '{index:1, v:20}, '{index:9, v:30}};
    q2 = arr.find(item, iter_index) with (item.index != item.iter_index);
    $display("I1 %0d %0d", q2.size(), q2[0].v);
  end
endmodule
