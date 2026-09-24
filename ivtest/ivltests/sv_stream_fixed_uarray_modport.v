// A streaming slice read obeys the same modport membership rule as an
// ordinary interface-property read (IEEE 1800-2017/2023 25.5).
interface stream_slice_if;
  bit [7:0] visible [0:2];
  bit [7:0] hidden [0:2];
  modport restricted(input visible);
  modport readable(input visible, hidden);
endinterface

module stream_slice_restricted(stream_slice_if.restricted bus);
  bit [23:0] got;
  initial got = {>>8{bus.hidden[0:2]}};
endmodule

module stream_slice_readable(stream_slice_if.readable bus,
                             output bit [23:0] got);
  initial begin
    #1;
    got = {>>8{bus.hidden[0:2]}};
  end
endmodule

module stream_slice_unrestricted(stream_slice_if bus,
                                 output bit [23:0] got);
  initial begin
    #1;
    got = {>>8{bus.hidden[0:2]}};
  end
endmodule

module stream_whole_restricted(stream_slice_if.restricted bus);
  bit [23:0] got;
  initial got = {>>8{bus.hidden}};
endmodule

module stream_whole_readable(stream_slice_if.readable bus,
                             output bit [23:0] got);
  initial begin
    #1;
    got = {>>8{bus.hidden}};
  end
endmodule

module stream_whole_unrestricted(stream_slice_if bus,
                                 output bit [23:0] got);
  initial begin
    #1;
    got = {>>8{bus.hidden}};
  end
endmodule

module stream_slice_bad_top;
  stream_slice_if bus();
  stream_slice_restricted bad(bus);
endmodule

module stream_whole_bad_top;
  stream_slice_if bus();
  stream_whole_restricted bad(bus);
endmodule

module stream_slice_good_top;
  stream_slice_if bus();
  bit [23:0] modport_got;
  bit [23:0] direct_got;
  bit [23:0] whole_modport_got;
  bit [23:0] whole_direct_got;
  stream_slice_readable listed(bus, modport_got);
  stream_slice_unrestricted direct(bus, direct_got);
  stream_whole_readable whole_listed(bus, whole_modport_got);
  stream_whole_unrestricted whole_direct(bus, whole_direct_got);
  initial begin
    bus.hidden[0] = 'h12;
    bus.hidden[1] = 'h34;
    bus.hidden[2] = 'h56;
    #2;
    if (modport_got !== 24'h123456 || direct_got !== 24'h123456 ||
        whole_modport_got !== 24'h123456 ||
        whole_direct_got !== 24'h123456)
      $fatal(1, "interface stream array read was wrong: %h %h %h %h",
             modport_got, direct_got, whole_modport_got, whole_direct_got);
    $display("PASSED");
  end
endmodule
