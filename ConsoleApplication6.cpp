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
                   Counter& invalid_input_total,
                   Counter& out_of_range_total) {

    checked_numbers_total.Increment();

    if (n < 1 || n > 2000000000) {
        std::cerr << "Error: Number is out of range (1 - 2 billion)." << std::endl;
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

    // Регистрация метрик (современный синтаксис)
    auto& checked_numbers_total = registry->AddMetricWithLabels<Counter>(
        "prime_checks_total", "Total checks", {});
    auto& prime_numbers_found_total = registry->AddMetricWithLabels<Counter>(
        "prime_numbers_found_total", "Total primes found", {});
    auto& invalid_input_total = registry->AddMetricWithLabels<Counter>(
        "invalid_input_total", "Total invalid inputs", {});
    auto& out_of_range_total = registry->AddMetricWithLabels<Counter>(
        "out_of_range_input_total", "Total out of range", {});

    bool interactive = isatty(fileno(stdin));
    std::thread exporter_thread(run_prometheus_exporter, PROMETHEUS_PORT, registry);

    if (interactive) {
        std::cout << "Enter numbers (1-2B). Type 'quit' to exit." << std::endl;
        std::string input_line;
        while (!stop_application) {
            std::cout << "> ";
            if (!std::getline(std::cin, input_line) || input_line == "quit") break;
            
            try {
                long long n = std::stoll(input_line);
                process_input(n, checked_numbers_total, prime_numbers_found_total, invalid_input_total, out_of_range_total);
            } catch (...) {
                invalid_input_total.Increment();
                std::cerr << "Invalid input." << std::endl;
            }
        }
    } else {
        std::string input_line;
        while (std::getline(std::cin, input_line)) {
            if (input_line.empty()) continue;
            try {
                long long n = std::stoll(input_line);
                process_input(n, checked_numbers_total, prime_numbers_found_total, invalid_input_total, out_of_range_total);
            } catch (...) {
                invalid_input_total.Increment();
            }
        }
    }

    stop_application = true;
    if (exporter_thread.joinable()) exporter_thread.join();
    return 0;
}