#include <iostream>
#include <atomic>
#include <string>
#include <thread>
#include <prometheus/exposer.h>
#include <prometheus/registry.h>
#include <prometheus/counter.h>
#include "httplib.h"

using namespace prometheus;

std::atomic<bool> running{true};

bool isPrime(long long n) {
    if (n <= 1) return false;
    if (n <= 3) return true;
    if (n % 2 == 0 || n % 3 == 0) return false;
    for (long long i = 5; i * i <= n; i += 6)
        if (n % i == 0 || n % (i + 2) == 0) return false;
    return true;
}

int main() {

    auto registry = std::make_shared<Registry>();

    auto& counter_family = BuildCounter()
        .Name("prime_checks_total")
        .Help("Total checks")
        .Register(*registry);

    auto& counter = counter_family.Add({});

    Exposer exposer{"0.0.0.0:9090"};
    exposer.RegisterCollectable(registry);

    httplib::Server svr;

    svr.Get("/check", [&](const httplib::Request& req, httplib::Response& res) {

        if (!req.has_param("num")) {
            res.set_content("Missing num", "text/plain");
            return;
        }

        long long n = std::stoll(req.get_param_value("num"));

        counter.Increment();

        if (isPrime(n)) {
            res.set_content(std::to_string(n) + " is prime", "text/plain");
        } else {
            res.set_content(std::to_string(n) + " is not prime", "text/plain");
        }
    });

    std::cout << "Server started on port 8080\n";
    svr.listen("0.0.0.0", 8080);

    return 0;
}