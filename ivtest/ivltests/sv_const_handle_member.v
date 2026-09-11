package const_handle_pkg;
  class item;
    int value;
    bit [7:0] bits;
    const int marker = 9;
  endclass
  const item shared = new;
endpackage
module sv_const_handle_member;
  import const_handle_pkg::*;
  const item local_handle = new;
  item alias_handle;
  task automatic change_local;
    const item temporary = new;
    temporary.value = 17;
    temporary.value += 3;
    if (temporary.value != 20) $fatal(1,"automatic handle member");
  endtask
  task automatic fill(output int x); x = 11; endtask
  task automatic bump(inout int x); x += 5; endtask
  initial begin
    alias_handle = shared;
    shared.value = 40;
    shared.value += 2;
    shared.bits[3:0] = 4'ha;
    local_handle.value = 7;
    local_handle.value++;
    if (alias_handle.value != 42 || alias_handle.bits != 8'h0a)
      $fatal(1,"package member or alias readback");
    if (local_handle.value != 8 || shared.marker != 9)
      $fatal(1,"local member or const member readback");
    fill(local_handle.value);
    bump(local_handle.value);
    if (local_handle.value != 16) $fatal(1,"output/inout member");
    change_local();
    if (shared != alias_handle) $fatal(1,"handle identity changed");
    $display("PASSED");
  end
endmodule
