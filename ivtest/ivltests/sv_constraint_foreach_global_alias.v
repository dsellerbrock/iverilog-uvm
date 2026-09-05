// IEEE1800-2017 18.3,18.5.8.1,18.5.9,18.5.13;2023 18.3,18.5.7.1,18.5.8,18.5.12.
package state_alias;
  class leaf;
    rand bit field;
    static rand bit shared;
    constraint c { field == 1; shared == 1; }
  endclass
  typedef struct { leaf ranges[$]; } device_t;
  device_t devices[$];
  class request;
    rand bit value;
    rand leaf active;
    function new(); active=new; endfunction
  endclass
endpackage
module main;
  import state_alias::*;
  request req; leaf other; device_t device; int selected=0;
  initial begin
    req=new; other=new;
    device.ranges.push_back(req.active); device.ranges.push_back(other);
    devices.push_back(device);
    req.active.field=0; req.active.shared=0;
    if(!req.randomize() with {
      foreach(devices[selected].ranges[i]) {
        devices[selected].ranges[i].shared == 1;
        if(i==0) devices[selected].ranges[i].field == 1;
        else devices[selected].ranges[i].field == 0;
      }
      value == active.field;
    } || req.active.field!=1 || req.value!=1 || other.field!=0 || other.shared!=1)
      $fatal(1,"active and static aliases");
    req.active.field=0;
    if(!req.randomize(value) with {
      foreach(devices[selected].ranges[i]) devices[selected].ranges[i].field == 0;
      value == 1;
    } || req.value!=1 || req.active.field!=0) $fatal(1,"explicit selection state");
    req.active.rand_mode(0); req.active.constraint_mode(0);
    if(!req.randomize() with {
      foreach(devices[selected].ranges[i]) devices[selected].ranges[i].field == 0;
      value == 1;
    } || req.active.field!=0) $fatal(1,"disabled child state");
    req.active.rand_mode(1); req.active.constraint_mode(1); req.value=0;
    if(req.randomize() with {
      foreach(devices[selected].ranges[i]) devices[selected].ranges[i].field == 0;
      value == 1;
    } || req.value!=0 || req.active.field!=0) $fatal(1,"alias conflict rollback");
    $display("PASSED");
  end
endmodule
