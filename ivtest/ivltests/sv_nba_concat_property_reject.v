`begin_keywords "1800-2012"

class nba_concat_holder;
  logic [7:0] value;
endclass

module sv_nba_concat_property_reject;
  nba_concat_holder obj;
  logic [7:0] plain;

  initial begin
    obj = new;
    // IVL exports the source-rightmost plain signal first. The target must
    // still find the property in the later l-value before generic lowering.
    {obj.value, plain} <= 16'h1234;
  end
endmodule

`end_keywords
