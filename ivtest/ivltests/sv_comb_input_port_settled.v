// An input port connection is a continuous assignment. The port sees the
// value after its always_comb driver suspends, including four-state values.
package sv_comb_port_pkg;
  function automatic logic [1:0] identity(input logic [1:0] value);
    return value;
  endfunction
endpackage

module sv_comb_port_observer(input logic [1:0] d);
  integer changes = 0;
  integer mirror_changes = 0;
  logic [1:0] last;
  wire [1:0] mirrored = d ^ 2'b00;
  always @(d) if ($time > 0) begin
    changes++;
    last = d;
  end
  always @(mirrored) if ($time > 0) mirror_changes++;
endmodule

module sv_comb_input_port_settled;
  logic [1:0] selected = 2'b00;
  logic touch = 1'b0;
  logic [1:0] driven;
  sv_comb_port_observer u_observer(.d(driven));

  always_comb begin
    driven = 2'b00;
    if (touch) driven = sv_comb_port_pkg::identity(selected);
    else       driven = sv_comb_port_pkg::identity(selected);
  end

  task automatic check(input logic [1:0] value, input integer expected_changes);
    selected = value;
    #1;
    if (u_observer.changes != expected_changes ||
        u_observer.last !== value || u_observer.d !== value || driven !== value)
      $fatal(1, "port value/event mismatch: value=%b changes=%0d",
             u_observer.d, u_observer.changes);
  endtask

  initial begin
    #1;
    check(2'b01, 1);
    if (u_observer.mirror_changes != 1)
      $fatal(1, "internal port consumer missed the settled value");
    touch = 1'b1;
    #1;
    if (u_observer.changes != 1 || u_observer.mirror_changes != 1 ||
        u_observer.d !== 2'b01)
      $fatal(1, "unchanged final port value generated an event");
    check(2'bxx, 2);
    touch = 1'b0;
    #1;
    if (u_observer.changes != 2 || u_observer.d !== 2'bxx)
      $fatal(1, "unchanged X port value generated an event");
    check(2'bzz, 3);
    check(2'b10, 4);
    check(2'b10, 4);
    check(2'b00, 5);
    $display("PASSED");
    $finish(0);
  end
endmodule
