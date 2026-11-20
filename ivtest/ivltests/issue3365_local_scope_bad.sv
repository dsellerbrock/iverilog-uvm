class issue3365_Cfg;
  static int value = 7;
endclass

class issue3365_Base;
  int member = 11;
endclass

class issue3365_Derived extends issue3365_Base;
  int own_member = 13;

  function int read_members();
    int lhs, rhs;
    lhs = local::this.own_member;
    rhs = local::super.member;
    return lhs + rhs;
  endfunction
endclass

class issue3365_Target;
  rand int x;
endclass

module issue3365_local_scope_bad;
  int y = 3, z;
  issue3365_Derived derived;
  issue3365_Target obj;

  task read_config();
    local::z = local::issue3365_Cfg::value;
  endtask

  initial begin
    z = local::y;
    read_config();
    derived = new;
    z = derived.read_members();
    obj = new;
    if (!local::obj.randomize() with { x == local::y; })
      $fatal(1, "randomize failed");
    z = local::y;
  end
endmodule
