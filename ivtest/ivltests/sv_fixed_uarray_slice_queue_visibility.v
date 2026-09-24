// IEEE 1800-2017/2023 8.18: a declaring class sees its local member, and
// a derived class sees an inherited protected member.
class base_t;
  local bit [7:0] secret[3:0];
  protected bit [7:0] shared[3:0];

  function new;
    foreach (secret[i]) secret[i] = i + 10;
    foreach (shared[i]) shared[i] = i + 20;
  endfunction

  task check_local;
    bit [7:0] q[$];
    q = secret[3:2];
    if (q.size() != 2 || q[0] != 13 || q[1] != 12)
      $fatal(1, "same-class local slice access");
  endtask
endclass

class child_t extends base_t;
  task check_protected;
    bit [7:0] q[$];
    q = shared[3:2];
    if (q.size() != 2 || q[0] != 23 || q[1] != 22)
      $fatal(1, "derived-class protected slice access");
  endtask
endclass

module test;
  child_t object;
  initial begin
    object = new;
    object.check_local();
    object.check_protected();
    $display("PASSED");
  end
endmodule
