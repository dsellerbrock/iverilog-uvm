// Edition boundary, next-edition arm: IEEE 1800-2009 must retain the
// iterator index querying standardized in IEEE 1800-2005 5.15.4.
module sv_edition_iter_index_neighbour;
  int arr[5] = '{5,1,2,3,4};
  int s;
  int q[$];
  initial begin
    s = arr.sum with (item.index);
    q = arr.find with (item == 4 && item.index == 4);
    if (s == 10 && q.size() == 1 && q[0] == 4) $display("PASSED");
    else $display("FAILED -- sum=%0d size=%0d value=%0d, expected 10, 1, 4",
                  s, q.size(), q.size() ? q[0] : -1);
  end
endmodule
