package p;
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
endpackage

module leaf #(parameter int N = 0);
  typedef p::registry #(N) test_t;
endmodule

module top;
  leaf #(1) a();
  leaf #(2) b();
  initial begin
    #1;
    if (p::registrations[1] == 1 && p::registrations[2] == 1 &&
        p::registrations[0] == 0)
      $display("PASSED");
    else
      $fatal(1, "FAILED 1=%0d 2=%0d 0=%0d",
             p::registrations[1], p::registrations[2],
             p::registrations[0]);
  end
endmodule
