// A legal IEEE 1800-2017 form that remains deliberately loud until an
// unbounded NBA snapshot is represented in the netlist.
module test;
  byte data[];
  byte tag;
  initial begin
    {>>{tag, data}} <= 24'h04_05_06;
  end
endmodule
