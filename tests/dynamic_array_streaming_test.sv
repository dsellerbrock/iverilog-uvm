// Streaming concatenation over a dynamic array/queue assigned to a dynamic
// (byte) array target: {<<N{queue}} and a variable-bound queue slice
// {<<N{q[lo:hi]}}.  Previously iverilog's fixed-width NetEConcat lowering
// silently miscompiled this (wrong element count) or errored on a variable
// slice.  This is the OpenTitan usb20_monitor pattern
//   data = {<<{destuffed_packet[16:15+len_bits]}}.
//
// Bit-exact reference (verified against iverilog's correct *packed* streaming):
//   q = {1,1,0,0,0,1,1,1, 0,0,1,1,1,1,1,1} packs to 16'hC73F
//   {<<1{q}} = bit-reverse(C73F) = FCE3 -> bytes {FC, E3}
//   {<<8{q}} = byte-reverse(C73F) = 3FC7 -> bytes {3F, C7}
module dynamic_array_streaming_test;
  bit q[$];
  initial begin
    byte unsigned d1[], d8[], dslice[];
    int unsigned n;
    bit src[16] = '{1,1,0,0,0,1,1,1, 0,0,1,1,1,1,1,1};
    foreach (src[i]) q.push_back(src[i]);

    d1 = {<<1{q}};           // bit-reverse  -> FC E3
    d8 = {<<8{q}};           // byte-reverse -> 3F C7

    // variable-bound slice (runtime position+width): prepend 32 bits, slice
    // them back out and stream.
    begin
      bit q2[$];
      for (int i = 0; i < 32; i++) q2.push_back(0);
      foreach (src[i]) q2.push_back(src[i]);
      n = q2.size() - 32;                 // 16, runtime
      dslice = {<<1{q2[32:31+n]}};        // -> FC E3
    end

    if (d1.size()==2     && d1[0]==8'hFC && d1[1]==8'hE3 &&
        d8.size()==2     && d8[0]==8'h3F && d8[1]==8'hC7 &&
        dslice.size()==2 && dslice[0]==8'hFC && dslice[1]==8'hE3)
      $display("PASS d1=%02h%02h d8=%02h%02h slice=%02h%02h",
               d1[0],d1[1], d8[0],d8[1], dslice[0],dslice[1]);
    else
      $display("FAIL d1.sz=%0d %02h%02h d8.sz=%0d %02h%02h slice.sz=%0d %02h%02h",
               d1.size(),d1[0],d1[1], d8.size(),d8[0],d8[1],
               dslice.size(),dslice[0],dslice[1]);
    $finish;
  end
endmodule
