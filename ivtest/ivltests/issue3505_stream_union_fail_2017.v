module issue3505_stream_union_fail;
  union { int first; bit [7:0] second; } word_union;
  union { real first; int second; } real_union;
  initial begin
    {>>{word_union}} = 8'hff;
    {>>{real_union}} = 64'h0;
  end
endmodule
