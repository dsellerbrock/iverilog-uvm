// IEEE1800-2017/2023 11.6.1,11.8.2;2017 18.5.8.1/18.5.13;2023 18.5.7.1/18.5.12.
package typed_guard;
  typedef struct { int field; } leaf_t;
  typedef struct { leaf_t ranges[$]; } device_t;
  device_t devices[$];
  class child;
    rand bit [7:0] field;
    constraint c { field == 7; }
  endclass
  class request;
    rand child active;
    rand bit value;
    bit enabled;
    function new(); active=new; endfunction
  endclass
endpackage
module main;
  import typed_guard::*;
  request req; device_t device; leaf_t leaf; int selected=0;
  initial begin
    req=new; leaf.field=0; device.ranges.push_back(leaf); devices.push_back(device);
    req.value=1; req.active.field=12;
    if(req.randomize() with {
      foreach(devices[selected].ranges[i]) devices[selected].ranges[i].field==0;
      value==0;
      if ((~(enabled ? active.field : 1'b0)) == 8'hff) value==1;
    } || req.value!=1 || req.active.field!=12) $fatal(1,"inactive random arm lost width or rollback");
    $display("PASSED");
  end
endmodule
