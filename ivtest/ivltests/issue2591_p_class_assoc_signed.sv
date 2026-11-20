module issue2591_p_class_assoc_signed;
  typedef enum bit [1:0] {IDLE, BUSY} state_t;
  typedef struct packed {
    logic [3:0] flags;
    state_t state;
  } record_t;

  class holder;
    int m[int];
  endclass

  class other_maps;
    int u[int unsigned];
    int b[byte];
    int fallback[int];
    bit [2:0] empty_bits[int];
    logic [3:0] empty_logic[int];
    state_t states[int];
    record_t records[int];
    string strings[int];
    holder objects[int];
  endclass

  holder h, copy;
  other_maps other;

  task automatic check_map(holder obj);
    int visited;
    if (obj.m.num() != 2 || obj.m[-1] !== 10 || obj.m[3] !== 30)
      $fatal(1, "signed map contents");
    visited = 0;
    foreach (obj.m[key]) begin
      if (key != (visited == 0 ? -1 : 3))
        $fatal(1, "signed map foreach at %0d: %0d", visited, key);
      visited++;
    end
    if (visited != 2)
      $fatal(1, "signed map foreach count %0d", visited);
  endtask

  task automatic check(string observed, string expected);
    if (observed != expected)
      $fatal(1, "expected %s, got %s", expected, observed);
  endtask

  initial begin
    h = new;
    other = new;
    h.m[3] = 30;
    h.m[-1] = 10;
    other.u[3] = 30;
    other.u[32'hffffffff] = 10;
    other.b[-1] = -7;
    other.b[-128] = -20;
    other.b[3] = 30;
    other.fallback = '{default:-42};
    other.states[-2] = BUSY;
    other.records[-3] = '{flags:4'b10xz, state:IDLE};
    other.strings[-4] = "a\"b\\";
    other.objects[2] = null;
    other.objects[-5] = h;

    check_map(h);
    if (other.fallback.num() != 0 || other.fallback[5] !== -42)
      $fatal(1, "empty explicit-default map before display");
    $display("%p", h.m);
    check($sformatf("%p", h.m), "'{-1:10, 3:30}");
    check($sformatf("%p", h), "'{m:'{-1:10, 3:30}}");
    check($sformatf("%p", other.u), "'{3:30, 4294967295:10}");
    check($sformatf("%p", other.b), "'{-128:-20, -1:-7, 3:30}");
    check($sformatf("%p", other.fallback), "'{default:-42}");
    check($sformatf("%p", other.empty_bits), "'{default:'0}");
    check($sformatf("%p", other.empty_logic), "'{default:'x}");
    check($sformatf("%p", other.states), "'{-2:BUSY}");
    check($sformatf("%p", other.records), "'{-3:'{flags:4'b10xz, state:IDLE}}");
    check($sformatf("%p", other.strings), "'{-4:\"a\\\"b\\\\\"}");
    check($sformatf("%p", other.objects), "'{-5:'{m:'{-1:10, 3:30}}, 2:null}");
    check_map(h);
    if (other.fallback.num() != 0 || other.fallback[5] !== -42)
      $fatal(1, "empty explicit-default map after display");
    other.fallback[3] = 30;
    check($sformatf("%p", other.fallback), "'{3:30, default:-42}");

    copy = new h;
    check($sformatf("%p", copy.m), "'{-1:10, 3:30}");
    $display("PASSED");
  end
endmodule
