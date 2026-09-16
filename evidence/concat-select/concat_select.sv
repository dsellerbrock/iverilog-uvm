module t;
  string qa[$] = {"aa", "bb"};
  string qb[$] = {"cc", "dd"};
  string s;
  initial begin
    s = {qa, qb}[1];
    $display("s=%s", s);
  end
endmodule
