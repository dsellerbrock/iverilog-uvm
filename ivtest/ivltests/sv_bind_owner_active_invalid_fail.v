// IEEE 1800-2017/2023 23.11: a bind declared in an active module occurrence
// must diagnose an unresolved definition target. This is the active partner
// to the excluded/inactive-owner cases, which must remain semantically absent.
module sv_bind_owner_active_invalid_probe;
endmodule

module sv_bind_owner_active_invalid_binder;
  bind sv_bind_owner_active_invalid_missing
    sv_bind_owner_active_invalid_probe p();
endmodule

module sv_bind_owner_active_invalid_fail;
  sv_bind_owner_active_invalid_binder live_owner();
endmodule
