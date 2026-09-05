// IEEE 1800-2017/2023 8.18: symbolic indices cannot bypass access control.
class region;
  local int lo;
endclass
class device;
  region ranges[$];
endclass
class hidden_device;
  protected region ranges[$];
endclass
class request;
  rand int addr;
endclass
module main;
  device devices[$];
  hidden_device hidden[$];
  request req;
  int selected;
  initial begin
    req = new;
    if (!req.randomize() with {
      foreach (devices[selected].ranges[i]) addr == devices[selected].ranges[i].lo;
    }) $finish;
    if (!req.randomize() with {
      foreach (hidden[selected].ranges[i]) addr == 1;
    }) $finish;
  end
endmodule
