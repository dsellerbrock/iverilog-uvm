module p06_24c;
  int pass = 0, fail = 0;
  task automatic ck(input string id, input bit c);
    if (c) pass++; else begin fail++; $display("FAIL %s", id); end
  endtask
  typedef struct { shortint address; logic [3:0] code; byte command[2]; } Control;
  typedef bit [35:0] bits36_t;
  typedef struct { byte length; shortint address; byte payload[]; byte chksum; } Packet;
  typedef byte channel_type[$];
  typedef byte b4_t[4];
  Control p, q;  bits36_t b36;  Packet pk, rk;  channel_type channel;
  int size, iv;  b4_t ba;  string str;  byte dq[$];
  initial begin
    p.address = 16'h1234; p.code = 4'ha; p.command[0] = 8'h56; p.command[1] = 8'h78;
    b36 = bits36_t'(p);
    ck("struct_to_bits_msb_first", b36 == {16'h1234, 4'ha, 8'h56, 8'h78});
    q = Control'(b36);
    ck("bits_to_struct", q.address == 16'h1234 && q.code == 4'ha && q.command[0] == 8'h56 && q.command[1] == 8'h78);
    pk.length = 2; pk.address = 16'h1234; pk.payload = '{8'hAA, 8'hBB}; pk.chksum = 8'h11;
    channel = channel_type'(pk);
    ck("packet_to_bytes", channel.size() == 6 && channel[0] == 2 && channel[1] == 8'h12 && channel[2] == 8'h34 && channel[3] == 8'hAA && channel[5] == 8'h11);
    size = channel[0] + 4; rk = Packet'(channel[0:size - 1]);
    ck("bytes_to_packet_greedy", rk.length == 2 && rk.address == 16'h1234 && rk.payload.size() == 2 && rk.payload[1] == 8'hBB && rk.chksum == 8'h11);
    ba = b4_t'(32'h01020304);  ck("int_to_bytes", ba[0] == 1 && ba[3] == 4);
    iv = int'(ba);             ck("bytes_to_int", iv == 32'h01020304);
    str = "AB"; dq = channel_type'(str);
    ck("string_to_bytes", dq.size() == 2 && dq[0] == "A" && dq[1] == "B");
    str = string'(dq);         ck("bytes_to_string", str == "AB");
    $display("RESULT pass=%0d fail=%0d", pass, fail);
  end
endmodule
