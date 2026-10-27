# IEEE 1800 stochastic queue tasks

IEEE 1800-2017 §20.16 and 1800-2023 §20.15 define `$q_initialize`, `$q_add`, `$q_remove`, `$q_full`, and `$q_exam`. Both editions use FIFO type 1 and LIFO type 2 (§20.16.1 / §20.15.1, Table 20-9).

The queue-statistic codes in Table 20-10 (2017 p. 618; 2023 p. 647) are:

| `q_stat_code` | `q_stat_value` |
| ---: | --- |
| 1 | Current queue length |
| 2 | Mean interarrival time |
| 3 | Maximum queue length |
| 4 | Shortest wait time ever |
| 5 | Longest wait time for jobs still in the queue |
| 6 | Average wait time in the queue |

The status values in §20.16.6 / §20.15.6, Table 20-11 (2017 p. 619; 2023 p. 648) are:

| Status | Meaning |
| ---: | --- |
| 0 | OK |
| 1 | Queue full, cannot add |
| 2 | Undefined `q_id` |
| 3 | Queue empty, cannot remove |
| 4 | Unsupported queue type, cannot create queue |
| 5 | Specified length <= 0, cannot create queue |
| 6 | Duplicate `q_id`, cannot create queue |
| 7 | Not enough memory, cannot create queue |

Both editions give the task syntax in §20.16 / §20.15 as `$q_initialize(q_id, q_type, max_length, status)`, `$q_add(q_id, job_id, inform_id, status)`, `$q_remove(q_id, job_id, inform_id, status)`, `$q_full(q_id, status)`, and `$q_exam(q_id, q_stat_code, q_stat_value, status)`. `$q_full` returns 0 when not full and 1 when full.
