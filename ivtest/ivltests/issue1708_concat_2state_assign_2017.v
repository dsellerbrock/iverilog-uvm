module issue1708_concat_2state_assign;
  bit [1:0] b;
  logic [2:0] g;
  bit [1:0] z_b;
  logic [2:0] z_g;
  bit [1:0] selected;
  bit [1:0] compound_b;
  logic [2:0] compound_g;
  logic [4:0] source = 5'bxxxxx;

  initial begin
    {b, g} = source;
    {z_b, z_g} = 5'bzzzzz;
    selected = source[4:3];
    {compound_b, compound_g} += 5'bxxxxx;
    $display("%b %b", b, g);
    $display("%b %b", z_b, z_g);
    $display("%b", selected);
    $display("%b %b", compound_b, compound_g);
  end
endmodule
