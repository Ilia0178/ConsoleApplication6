#include "httplib.h"
#include <prometheus/exposer.h>
#include <prometheus/registry.h>
#include <prometheus/counter.h>

using namespace httplib;
using namespace prometheus;

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
    auto registry = std::make_shared<Registry>();

    auto& counter = BuildCounter()
        .Name("prime_checks_total")
        .Help("checks")
        .Register(*registry)
        .Add({});

    auto& found = BuildCounter()
        .Name("prime_found_total")
        .Help("found")
        .Register(*registry)
        .Add({});

    // Prometheus metrics
    Exposer exposer{"0.0.0.0:9090"};
    exposer.RegisterCollectable(registry);

    // HTTP server
    Server svr;

    svr.Get("/check", [&](const Request& req, Response& res) {
        auto num = std::stoll(req.get_param_value("num"));

        counter.Increment();

        if (isPrime(num)) {
            found.Increment();
            res.set_content(std::to_string(num) + " is prime", "text/plain");
        } else {
            res.set_content(std::to_string(num) + " is not prime", "text/plain");
        }
    });

    std::cout << "Server started on 8080\n";
    svr.listen("0.0.0.0", 8080);
}