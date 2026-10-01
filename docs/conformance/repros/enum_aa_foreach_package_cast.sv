package values_pkg;
  typedef logic [319:0] state_t;
  typedef enum state_t {A = 320'h1, B = 320'h2} state_e;
  string label[state_e] = '{A: "a", B: "b"};
endpackage

package env_pkg;
  import values_pkg::*;
  class helper;
    virtual function void consume(values_pkg::state_e state);
      if (label[state] == "") $fatal(1, "missing label");
    endfunction
  endclass
  class driver_sequence;
    typedef enum {Otp} memory_e;
    helper helpers[memory_e];
    task run();
      helpers[Otp] = new;
      foreach (values_pkg::label[state]) helpers[Otp].consume(values_pkg::state_e'(state));
    endtask
  endclass
endpackage

module top;
  env_pkg::driver_sequence seq;
  initial begin
    seq = new;
    seq.run();
    $display("PASS package enum foreach");
  end
endmodule
