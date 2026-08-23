// A bare parameterized class name in an extends clause denotes the same
// default specialization as a bare handle declaration and an explicit #().
// Keep the derived class's runtime ancestry on that one canonical type.
module sv_param_class_bare_base_identity;
  class item;
  endclass

  class other_item;
  endclass

  class base #(type REQ = item, type RSP = REQ);
  endclass

  class derived extends base;
  endclass

  base bare_base;
  base#() explicit_base;
  base#(other_item) other_base;
  derived child;

  initial begin
    child = new;
    if (!$cast(bare_base, child)) begin
      $display("FAILED bare default base cast");
      $finish(1);
    end
    if (!$cast(explicit_base, child)) begin
      $display("FAILED explicit default base cast");
      $finish(1);
    end
    if ($cast(other_base, child)) begin
      $display("FAILED distinct specialization base cast");
      $finish(1);
    end
    $display("PASSED");
  end
endmodule
