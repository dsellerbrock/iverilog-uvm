// Legal residual: target lowering does not yet carry a run-time-sized stream
// remainder through a class-property l-value chain. Keep it loud.
module test;
  class holder;
    byte data[];
  endclass
  holder h;
  byte tag;
  initial begin
    h = new;
    {>>{tag, h.data}} = 24'h01_02_03;
  end
endmodule
