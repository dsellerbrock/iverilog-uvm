// Deferred cover needs the same per-process queue plus cover accounting.
// Stage 1 refuses it loudly instead of silently discarding the item.
module t;
  initial cover #0 (1);
endmodule
