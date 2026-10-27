module p10_10_nested_string_concat_item;
  string S1, S2;
  string SQ[$];
  initial begin
    S1 = "S1";
    S2 = "S2";
    SQ = '{"element 0", "element 1"};
    SQ = {S1, SQ, {"element 3 is ", S2}};
    $display("SQ %0d %s %s %s", SQ.size(), SQ[0], SQ[1], SQ[3]);
  end
endmodule
