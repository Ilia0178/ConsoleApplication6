#include <iostream>
#include <string>
#include <atomic>
#include <csignal>
#include <memory>
#include <thread>
#include <chrono>

#include "httplib.h"

#include <prometheus/exposer.h>
#include <prometheus/registry.h>
#include <prometheus/counter.h>

using namespace prometheus;

std::atomic<bool> running{true};

static inline void signal_handler(int signal) {
    if (signal == SIGINT || signal == SIGTERM) {
        running.store(false, std::memory_order_relaxed);
    }
} 

// быстрее и чуть чище проверка
bool isPrime(long long n) {
    if (n < 2) return false;
    if (n % 2 == 0) return n == 2;
    if (n % 3 == 0) return n == 3;

    for (long long i = 5; i * i <= n; i += 6) {
        if (n % i == 0 || n % (i + 2) == 0)
            return false;
    }
    return true;
}

int main() {
    std::signal(SIGINT, signal_handler);
    std::signal(SIGTERM, signal_handler);

    auto registry = std::make_shared<Registry>();

    auto& checks = BuildCounter()
        .Name("prime_checks_total")
        .Help("Total requests")
        .Register(*registry)
        .Add({});

    auto& found = BuildCounter()
        .Name("prime_found_total")
        .Help("Total primes found")
        .Register(*registry)
        .Add({});

    // Prometheus endpoint (keep minimal overhead)
    Exposer exposer{"0.0.0.0:9090"};
    exposer.RegisterCollectable(registry);

    httplib::Server svr;

    // reduce allocations (static responses)
    static const std::string ok = "OK";
    static const std::string bad_request = "invalid number";

    svr.Get("/", [&](const httplib::Request&, httplib::Response& res) {
        res.set_content(ok, "text/plain");
    });

    svr.Get("/check", [&](const httplib::Request& req, httplib::Response& res) {
        const auto& num_str = req.get_param_value("num");

        if (num_str.empty()) {
            res.status = 400;
            res.set_content("missing num", "text/plain");
            return;
        }

        long long n;
        try {
            n = std::stoll(num_str);
        } catch (...) {
            res.status = 400;
            res.set_content(bad_request, "text/plain");
            return;
        }

        checks.Increment();

        if (isPrime(n)) {
            found.Increment();
            res.set_content(num_str + " is prime", "text/plain");
        } else {
            res.set_content(num_str + " is not prime", "text/plain");
        }
    });

    std::cout << "Server started on 8080\n";

    // run server in background thread
    std::thread server_thread([&]() {
        svr.listen("0.0.0.0", 8080);
    });

    // low CPU idle loop
    while (running.load(std::memory_order_relaxed)) {
        std::this_thread::sleep_for(std::chrono::milliseconds(200));
    }

    svr.stop();
    server_thread.join();

    return 0;
}