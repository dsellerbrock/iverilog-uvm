// IEEE 1800-2017/2023 11.4.14.3 and 11.4.14.4.
class issue3865_packet;
  rand byte tag;
  rand byte payload[];
  byte suffix;
  constraint tag_limit { tag == 0; }
endclass

class issue3865_footer;
  byte value;
endclass

class issue3865_derived extends issue3865_packet;
  issue3865_footer footer;
  string label;
endclass

class issue3865_queue;
  logic [4:0] words[$:1];
  bit [3:0] suffix;
endclass

class issue3865_text;
  string value;
  byte suffix;
endclass

class issue3865_text_box;
  issue3865_text inner;
endclass

module issue3865_class_greedy;
  issue3865_packet p, alias_p, absent, replacement;
  issue3865_derived derived;
  issue3865_footer alias_footer;
  issue3865_footer footer_slots[1];
  issue3865_queue bounded;
  issue3865_text text;
  issue3865_text_box box;
  byte q[$], trailer;
  string later_text;
  int rebind_calls;

  function automatic int rebind_packet();
    rebind_calls++;
    p = replacement;
    return 0;
  endfunction

  initial begin
    p = new;
    alias_p = p;
    p.rand_mode(0);
    p.tag_limit.constraint_mode(0);
    q.push_back(8'hff);
    {>>{p, q, trailer}} = 40'h1122334455;
    if (p.tag !== 8'h11 || p.payload.size() != 2 ||
        p.payload[0] !== 8'h22 || p.payload[1] !== 8'h33 ||
        p.suffix !== 8'h44 || q.size() != 0 || trailer !== 8'h55)
      $fatal(1, "unallocated class payload takes the remainder");
    if (p != alias_p || p.tag.rand_mode() !== 0 ||
        p.payload[0].rand_mode() !== 0 || p.tag_limit.constraint_mode() !== 0)
      $fatal(1, "class identity and randomization modes must survive unpack");

    derived = new;
    derived.footer = new;
    alias_footer = derived.footer;
    derived.payload = new[3];
    derived.label = "old";
    {>>{absent, q, derived, trailer}} = 56'hA1B2C312345678;
    if (absent != null || q.size() != 3 ||
        q[0] !== 8'ha1 || q[1] !== 8'hb2 || q[2] !== 8'hc3 ||
        derived.tag !== 8'h12 || derived.payload.size() != 0 ||
        derived.suffix !== 8'h34 || derived.footer != alias_footer ||
        derived.footer.value !== 8'h56 || derived.label.len() != 0 ||
        trailer !== 8'h78)
      $fatal(1, "ordinary greedy peer reserves inherited and nested fixed fields");

    // Inverting the blocks yields 61, then B3 and two more payload bits,
    // then 72 and 83. The last payload byte is padded on the right.
    {<<8{p, q, trailer}} = 34'b10000011_01110010_11001110_10000110_01;
    if (p.tag !== 8'h61 || p.payload.size() != 2 ||
        p.payload[0] !== 8'hb3 || p.payload[1] !== 8'h80 ||
        p.suffix !== 8'h72 || q.size() != 0 || trailer !== 8'h83)
      $fatal(1, "inverse permutation of the selected span");

    {>>{derived.tag, derived.payload, derived.footer.value, trailer}} =
        40'h90A1B2C3D4;
    if (derived.tag !== 8'h90 || derived.payload.size() != 2 ||
        derived.payload[0] !== 8'ha1 || derived.payload[1] !== 8'hb2 ||
        derived.suffix !== 8'h34 || alias_footer.value !== 8'hc3 ||
        trailer !== 8'hd4)
      $fatal(1, "explicit property peers store into their captured owners");

    replacement = new;
    footer_slots[0] = alias_footer;
    {>>{p.payload, footer_slots[rebind_packet()], trailer}} = 32'h56789ABC;
    if (rebind_calls != 1 || p != replacement || p.payload.size() != 0 ||
        alias_p.payload.size() != 2 || alias_p.payload[0] !== 8'h56 ||
        alias_p.payload[1] !== 8'h78 || alias_footer.value !== 8'h9a ||
        trailer !== 8'hbc)
      $fatal(1, "a later receiver selection cannot retarget an earlier property");

    bounded = new;
    {>>{bounded}} = 12'b10x1z_101_0110;
    if (bounded.words.size() != 2 || bounded.words[0] !== 5'b10x1z ||
        bounded.words[1] !== 5'b10100 || bounded.suffix !== 4'h6)
      $fatal(1, "queue element width, state domain and final partial element");
    {>>{bounded}} = 19'b00101_10101_11111_0111;
    if (bounded.words.size() != 2 || bounded.words[0] !== 5'b00101 ||
        bounded.words[1] !== 5'b10101 || bounded.suffix !== 4'h7)
      $fatal(1, "bounded queue consumes the remainder and discards excess elements");

    text = new;
    box = new;
    box.inner = text;
    later_text = "old";
    {>>{box, later_text, trailer}} = 40'h41005AAABB;
    if (box.inner != text || text.value.len() != 2 || text.value != "AZ" ||
        text.suffix !== 8'haa || later_text.len() != 0 || trailer !== 8'hbb)
      $fatal(1, "string property takes the remainder and clears a later string");

    $display("PASSED");
  end
endmodule
