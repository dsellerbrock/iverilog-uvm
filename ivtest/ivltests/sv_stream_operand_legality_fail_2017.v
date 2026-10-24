module test;
  int a = 5;
  int x;
  real r = 1.5;
  initial begin
    x = {>>{a}} + 1;
    x = {>>{r}};
  end
endmodule
