package nested_registry_pkg;
  int registrations[int];
  class registry #(int N = 0);
    static registry #(N) me = get();
    static function registry #(N) get();
      if (me == null) begin
        me = new;
        registrations[N]++;
      end
      return me;
    endfunction
  endclass
  class holder #(int N = 0);
    typedef registry #(N) type_id;
  endclass
  class plain_holder;
    typedef registry #(4) type_id;
  endclass
  typedef holder #(2) package_holder_t;
  typedef plain_holder plain_holder_t;
endpackage

module top;
  typedef nested_registry_pkg::holder #(3) module_holder_t;
  initial begin
    #1;
    if (nested_registry_pkg::registrations[2] == 1 &&
        nested_registry_pkg::registrations[3] == 1 &&
        nested_registry_pkg::registrations[4] == 1 &&
        nested_registry_pkg::registrations[0] == 0)
      $display("PASSED");
    else
      $fatal(1, "FAILED 2=%0d 3=%0d 4=%0d 0=%0d",
        nested_registry_pkg::registrations[2],
        nested_registry_pkg::registrations[3],
        nested_registry_pkg::registrations[4],
        nested_registry_pkg::registrations[0]);
  end
endmodule
