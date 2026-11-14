module issue2416_stream_queue;
  bit [31:0] q[$];
  logic [127:0] wide[$];
  logic [7:0] four[$];
  bit [7:0] two[$];
  bit [7:0] bounded[$:2];
  bit [7:0] dynamic_array[];
  integer i;
  initial begin
    q.push_back(1); q.push_back(2);
    {>>{q[0], q[1]}} = 64'(5);
    if (q[0] !== 0 || q[1] !== 5) $fatal(1, "32-bit unpack");
    wide.push_back('0); wide.push_back('0);
    {>>{wide[0], wide[1]}} = 256'h0123456789abcdef0123456789abcdef_fedcba9876543210fedcba9876543210;
    if (wide[0] !== 128'h0123456789abcdef0123456789abcdef ||
        wide[1] !== 128'hfedcba9876543210fedcba9876543210) $fatal(1, "wide unpack");
    four.push_back('0); two.push_back('0);
    i = 0;
    {>>{four[i], two[i]}} = 16'haxz5;
    if (four[0] !== 8'hax || two[0] !== 8'h05) $fatal(1, "state conversion");
    bounded.push_back(8'h11);
    dynamic_array = new[1];
    {>>{bounded[1], dynamic_array[0]}} = 16'h5678;
    if (bounded.size() != 2 || bounded[1] !== 8'h56 ||
        dynamic_array[0] !== 8'h78) $fatal(1, "append and mixed containers");
    {<<8{bounded[0], bounded[1]}} = 16'h1234;
    if (bounded[0] !== 8'h34 || bounded[1] !== 8'h12) $fatal(1, "left stream");
    $display("PASS");
  end
endmodule
