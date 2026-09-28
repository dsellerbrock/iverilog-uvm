#include <algorithm>
#include <chrono>
#include <condition_variable>
#include <cstdio>
#include <cstdlib>
#include <mutex>
#include <thread>
#include <vector>

int main(int argc, char** argv)
{
    if (argc != 2) return 2;
    const int workers = std::atoi(argv[1]) - 1;
    if (workers < 1 || workers > 3) return 2;
    std::mutex lock;
    std::condition_variable wake, done;
    int generation = 0, remaining = 0;
    bool stop = false;
    std::vector<std::thread> threads;
    for (int i = 0; i < workers; ++i) {
        threads.emplace_back([&] {
            int seen = 0;
            for (;;) {
                std::unique_lock<std::mutex> guard(lock);
                wake.wait(guard, [&] { return stop || generation != seen; });
                if (stop) return;
                seen = generation;
                guard.unlock();
                asm volatile("" ::: "memory");
                guard.lock();
                if (--remaining == 0) done.notify_one();
            }
        });
    }
    std::vector<long long> ns;
    for (int round = 0; round < 11000; ++round) {
        const auto begin = std::chrono::steady_clock::now();
        {
            std::lock_guard<std::mutex> guard(lock);
            remaining = workers;
            ++generation;
        }
        wake.notify_all();
        {
            std::unique_lock<std::mutex> guard(lock);
            done.wait(guard, [&] { return remaining == 0; });
        }
        if (round >= 1000)
            ns.push_back(std::chrono::duration_cast<std::chrono::nanoseconds>(
                             std::chrono::steady_clock::now() - begin).count());
    }
    {
        std::lock_guard<std::mutex> guard(lock);
        stop = true;
    }
    wake.notify_all();
    for (auto& thread : threads) thread.join();
    std::sort(ns.begin(), ns.end());
    std::printf("cores=%d samples=%zu median_us=%.3f p90_us=%.3f p99_us=%.3f\n",
                workers + 1, ns.size(), ns[ns.size()/2]/1000.,
                ns[ns.size()*9/10]/1000., ns[ns.size()*99/100]/1000.);
}
