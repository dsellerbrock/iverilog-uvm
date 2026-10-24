# IEEE 1800 references for queue assignment probe

The normative examples are in IEEE 1800-2017 §7.10.4, p.164, and IEEE
1800-2023 §7.10.4, p.172. The method-equivalence rule says the resulting
queue value shall be the same as if the corresponding queue method had been
applied. Both editions give the same examples exercised here:

```systemverilog
q = { q, 6 };                    // q.push_back(6)
q = { e, q };                    // q.push_front(e)
q = q[1:$];                      // pop_front() or delete(0)
q = q[0:$-1];                    // pop_back() or delete(q.size-1)
q = { q[0:pos-1], e, q[pos:$] }; // insert(pos, e)
q = { q[0:pos], e, q[pos+1:$] };// insert(pos+1, e)
q = {};
q = q[2:$];
q = q[1:$-1];
```

IEEE 1800-2017 §7.10.3 and 2023 §7.10.3 additionally require references to
elements of the original queue to become outdated after whole-queue
assignment. That separate reference rule is covered by the existing
`p07_10_3_ref.sv` probe.
