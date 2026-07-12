// Assigning a streaming pack to a target with fewer bits than the
// stream is an error (IEEE 1800-2017 11.4.14; LRM example
// int j = {>>{a,b,c}} with 96 stream bits).
module g12_stream_target_too_small;
  bit [31:0] a, b, c;
  int j;
  initial begin
    j = {>>{a, b, c}};
  end
endmodule
