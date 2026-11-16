module issue670_psprintf;
  string fmt, value;
  initial begin
    fmt = "The agent at '%s' uses %s";
    value = $psprintf(fmt, "agent", "ifname", );
    if (value != "The agent at 'agent' uses ifname ") $fatal(1, "trailing: [%s]", value);
    value = $psprintf("<%s>", );
    if (value != "< >") $fatal(1, "consumed: [%s]", value);
    value = $psprintf("plain %%", );
    if (value != "plain % ") $fatal(1, "escape: [%s]", value);
    value = $psprintf("%0d", 42);
    if (value != "42") $fatal(1, "control: [%s]", value);
    $display("PASS");
  end
endmodule
