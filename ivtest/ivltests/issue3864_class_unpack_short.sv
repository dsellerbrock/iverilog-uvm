// The peer and all object leaves must be validated before any store.
class issue3864_short_packet;
  logic [7:0] first = 8'h12, second = 8'h34;
endclass

module issue3864_class_unpack_short;
  issue3864_short_packet p;
  logic [3:0] peer = 4'hf;
  initial begin
    p = new;
    {>>{peer, p}} = 19'b0;
    $fatal(1, "short unpack continued");
  end

  final begin
    if ({peer, p.first, p.second} !== 20'hf1234)
      $display("FAIL: short unpack modified a destination");
  end
endmodule
