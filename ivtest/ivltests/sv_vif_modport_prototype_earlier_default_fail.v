// IEEE 1800-2017/2023 13.5.3/25.7 permits a full prototype default to
// reference an earlier formal. Dynamic VIF dispatch does not yet carry the
// earlier binding into a later argument row, so it must reject rather than
// warn and substitute a stub value.
interface earlier_default_if;
  function int sum(input int first, input int second);
    return first + second;
  endfunction

  modport selected(import function int sum(
      input int first,
      input int second = first
  ));
endinterface

module sv_vif_modport_prototype_earlier_default_fail;
  earlier_default_if bus();
  virtual earlier_default_if.selected vif;
  int result;

  initial begin
    vif = bus.selected;
    result = vif.sum(3);
  end
endmodule
