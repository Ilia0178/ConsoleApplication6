#include <iostream>
#include <cmath>
#include <limits>
#include <clocale>
#include <thread>         
#include <atomic>         
#include <stdexcept>    
#include <string>          
#include <algorithm>
#include <sstream>     
#include <csignal>        
#include <unistd.h>       

#include <prometheus/exposer.h>
#include <prometheus/registry.h>
#include <prometheus/counter.h>

using namespace prometheus;

std::atomic<bool> stop_application = false;

void signal_handler(int signal) {
    if (signal == SIGINT || signal == SIGTERM) {
        std::cout << "\nПолучен сигнал завершения." << std::endl;
        stop_application = true;
    }
}

void run_prometheus_exporter(int port, std::shared_ptr<Registry> registry) {
    try {
        Exposer exposer{"0.0.0.0:" + std::to_string(port)};
        exposer.RegisterCollectable(registry);
        while (!stop_application) {
            std::this_thread::sleep_for(std::chrono::seconds(1)); 
        }
    } catch (const std::runtime_error& e) {
        std::cerr << "Exporter error: " << e.what() << std::endl;
    }
}

bool isPrime(long long n) {
    if (n <= 1) return false;
    if (n <= 3) return true;
    if (n % 2 == 0 || n % 3 == 0) return false;
    for (long long i = 5; i * i <= n; i += 6) {
        if (n % i == 0 || n % (i + 2) == 0) return false;
    }
    return true;
}

void process_input(long long n,
                   Counter& checked_numbers_total,
                   Counter& prime_numbers_found_total,
                   Counter& out_of_range_total) {

    checked_numbers_total.Increment();

    if (n < 1 || n > 2000000000) {
        std::cerr << "Error: Number is out of the valid range (1 - 2 billion)." << std::endl;
        out_of_range_total.Increment();
        return; 
    }

    if (isPrime(n)) {
        std::cout << n << " is a prime number." << std::endl;
        prime_numbers_found_total.Increment();
    } else {
        std::cout << n << " is not a prime number." << std::endl;
    }
}

int main() {
    std::signal(SIGINT, signal_handler);
    std::signal(SIGTERM, signal_handler);

    const int PROMETHEUS_PORT = 9090;
    auto registry = std::make_shared<Registry>();

    auto& checked_numbers_total = prometheus::BuildCounter()
        .Name("prime_checks_total")
        .Help("Total number of prime checks performed")
        .Register(*registry)
        .Add({});

    auto& prime_numbers_found_total = prometheus::BuildCounter()
        .Name("prime_numbers_found_total")
        .Help("Total number of prime numbers found")
        .Register(*registry)
        .Add({});

    auto& invalid_input_total = prometheus::BuildCounter()
        .Name("invalid_input_total")
        .Help("Invalid input counter")
        .Register(*registry)
        .Add({});

    auto& out_of_range_total = prometheus::BuildCounter()
        .Name("out_of_range_input_total")
        .Help("Out of range counter")
        .Register(*registry)
        .Add({});

    // 🚀 start exporter
    Exposer exposer{"0.0.0.0:" + std::to_string(PROMETHEUS_PORT)};
    exposer.RegisterCollectable(registry);

    std::cout << "Service started on port " << PROMETHEUS_PORT << std::endl;

    // 🔥 CRITICAL: KEEP CONTAINER ALIVE
    while (true) {
        std::this_thread::sleep_for(std::chrono::seconds(5));
    }

    return 0;
}