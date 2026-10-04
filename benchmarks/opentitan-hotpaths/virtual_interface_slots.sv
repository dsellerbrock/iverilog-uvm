interface bus_if;
  logic valid;
  logic [7:0] data;
  logic ready;
endinterface

class holder;
  virtual bus_if vif;

  function new(virtual bus_if target);
    vif = target;
  endfunction
endclass

module top;
  bus_if bus();
  holder h;
  int constructions;
  int checks;

  initial begin
    bus.valid = 0;
    bus.data = 0;
    bus.ready = 0;
    constructions = 0;
    checks = 0;
    repeat (64) begin
      h = new(bus);
      h.vif.valid = 1;
      h.vif.data = constructions[7:0];
      h.vif.ready = 1;
      #1;
      if (bus.valid !== 1 || bus.data !== constructions[7:0] || bus.ready !== 1)
        $fatal(1, "virtual interface slot did not resolve to the source interface");
      checks = checks + 1;
      constructions = constructions + 1;
      h = null;
    end
    $display("PASS virtual_interface_slots constructions=%0d members=3 checks=%0d",
             constructions, checks);
    $finish;
  end
endmodule
