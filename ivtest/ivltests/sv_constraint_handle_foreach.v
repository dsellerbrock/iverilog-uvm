// IEEE1800-2017/2023 8.4,11.4.5; 2017 18.5.8.1/18.5.9/18.5.13; 2023 18.5.7.1/18.5.8/18.5.12.
package state_handles;
  class leaf; leaf peer; int value=7; endclass
  typedef struct { leaf ranges[$]; } device_t;
  device_t devices[$];
  class child; rand bit field; constraint c { field == 1; } endclass
  class request; rand bit value; rand child active; function new(); active=new; endfunction endclass
endpackage
module main;
  import state_handles::*;
  request req; leaf item; device_t device; int selected=0;
  initial begin
    req=new; item=new; device.ranges.push_back(item); device.ranges.push_back(null);
    devices.push_back(device);
    if(!req.randomize() with {
      active.field == 1;
      foreach(devices[selected].ranges[i]) {
        if(devices[selected].ranges[i] != null) {
          value == 1;
          devices[selected].ranges[i].peer == null;
          devices[selected].ranges[i].value == 7;
        }
      }
    } || req.value!=1) $fatal(1,"state foreach handle guard");
    item.peer=item; req.value=0;
    if(req.randomize() with {
      foreach(devices[selected].ranges[i])
        if(devices[selected].ranges[i] != null) devices[selected].ranges[i].peer == null;
    } || req.value!=0) $fatal(1,"state foreach false identity or rollback");
    $display("PASSED");
  end
endmodule
