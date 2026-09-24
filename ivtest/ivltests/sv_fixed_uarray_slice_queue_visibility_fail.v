// A protected member is inaccessible externally, and a base local member
// is inaccessible even from a derived-class method.
class base_t;
  local bit [7:0] secret[3:0];
  protected bit [7:0] shared[3:0];
endclass

class child_t extends base_t;
  task bad_inherited_local;
    bit [7:0] q[$];
    q = secret[3:2];
  endtask
endclass

module test;
  child_t object;
  bit [7:0] q[$];
  initial begin
    object = new;
    q = object.shared[3:2];
    object.bad_inherited_local();
  end
endmodule
