// Edition gate, neighbour arm: the ordinary iterator `item' and the
// locator methods that do NOT use `index' are 1800-2012 syntax and must
// keep working under -g2012 -- the gate must cut at `index', not at
// array manipulation methods generally.
module sv_edition_iter_index_neighbour;
  int arr[5] = '{5,1,2,3,4};
  int s;
  int q[$];
  initial begin
    s = arr.sum with (item);
    q = arr.find with (item > 2);
    if (s == 15 && q.size() == 3) $display("PASSED");
    else $display("FAILED -- sum=%0d size=%0d, expected 15 and 3", s, q.size());
  end
endmodule
