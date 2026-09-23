module assoc_push_probe;
  int aa[int];
  initial begin
    aa.push_front(1);
    aa.push_back(2);
    aa.insert(0,3);
  end
endmodule
