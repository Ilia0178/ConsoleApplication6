#include <iostream>
#include <string>
#include <atomic>
#include <csignal>

#include "httplib.h"

#include <prometheus/exposer.h>
#include <prometheus/registry.h>
#include <prometheus/counter.h>

using namespace prometheus;

std::atomic<bool> running{true};

void signal_handler(int) {
    running = false;
}

bool isPrime(long long n) {
    if (n <= 1) return false;
    if (n <= 3) return true;
    if (n % 2 == 0 || n % 3 == 0) return false;
    for (long long i = 5; i * i <= n; i += 6)
        if (n % i == 0 || n % (i + 2) == 0)
            return false;
    return true;
}

int main() {
    std::signal(SIGINT, signal_handler);
    std::signal(SIGTERM, signal_handler);

    auto registry = std::make_shared<Registry>();

    auto& checks = BuildCounter()
        .Name("prime_checks_total")
        .Help("Total checks")
        .Register(*registry)
        .Add({});

    auto& found = BuildCounter()
        .Name("prime_found_total")
        .Help("Total primes found")
        .Register(*registry)
        .Add({});

    // Prometheus
    Exposer exposer{"0.0.0.0:9090"};
    exposer.RegisterCollectable(registry);

    // HTTP server
    httplib::Server svr;

    svr.Get("/check", [&](const httplib::Request& req, httplib::Response& res) {
        try {
            if (!req.has_param("num")) {
                res.status = 400;
                res.set_content("missing num", "text/plain");
                return;
            }

            long long n = std::stoll(req.get_param_value("num"));

            checks.Increment();

            if (isPrime(n)) {
                found.Increment();
                res.set_content(std::to_string(n) + " is prime", "text/plain");
            } else {
                res.set_content(std::to_string(n) + " is not prime", "text/plain");
            }
        }
        catch (...) {
            res.status = 400;
            res.set_content("invalid number", "text/plain");
        }
    });

    std::cout << "Server started on 8080\n";

    svr.listen("0.0.0.0", 8080);
}