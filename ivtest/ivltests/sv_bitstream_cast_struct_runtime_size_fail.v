typedef struct {
  byte first;
  byte second;
} pair_t;

module test;
  byte channel[$];
  pair_t pair_value;

  initial begin
    channel.push_back(8'h12);
    pair_value = pair_t'(channel);
    $display("FAILED");
  end
endmodule
