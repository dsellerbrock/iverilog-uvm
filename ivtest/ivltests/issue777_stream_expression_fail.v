module issue777_stream_expression_fail;
  int a = 5;
  int x;
  real r = 1.5;
  logic [63:0] y;

  initial begin
    x = int'({>>{a}});
    x = {>>{a}} + 1;
    x = ~{>>{a}};
    x = 1 ? {>>{a}} : 0;
    y = {>>{r}};
  end
endmodule
