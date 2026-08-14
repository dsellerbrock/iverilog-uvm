class vif_default_override_holder #(
  type IFType = virtual interface vif_default_override_missing_if
);
  IFType value;

  function IFType echo(input IFType item);
    return item;
  endfunction
endclass

module sv_typeparam_virtual_interface_default_override;
  vif_default_override_holder #(int) object;

  initial begin
    object = new;
    object.value = 41;
    if (object.echo(1) + object.value == 42)
      $display("PASSED");
    else
      $display("FAILED value=%0d", object.value);
  end
endmodule
