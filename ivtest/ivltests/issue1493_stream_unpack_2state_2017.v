module issue1493_stream_unpack_2state;
  logic [1:0] source;
  bit [1:0] target;

  initial begin
    source = 2'b1x;
    {>>{target}} = source;
    if (target !== 2'b10)
      $fatal(1, "issue1493: expected 10, got %b", target);
    $display("PASSED");
  end
endmodule
