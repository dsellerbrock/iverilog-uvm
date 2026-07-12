// A streaming unpack whose source provides fewer bits than the target
// needs is an error (IEEE 1800-2017 11.4.14.3; LRM example
// {>>{a,b,c}} = 23'b1).
module g12_stream_source_too_small;
  bit [7:0] a, b, c;
  initial begin
    {>>{a, b, c}} = 23'b1;
  end
endmodule
