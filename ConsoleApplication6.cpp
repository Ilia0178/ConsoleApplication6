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
#include <prometheus/gauge.h> 

using namespace prometheus;

std::atomic<long long> checked_numbers_count = 0;
std::atomic<long long> prime_numbers_found_count = 0;
std::atomic<long long> invalid_input_count = 0;
std::atomic<long long> out_of_range_count = 0;

std::atomic<bool> stop_application = false;

void signal_handler(int signal) {
    if (signal == SIGINT || signal == SIGTERM) {
        std::cout << "\nПолучен сигнал завершения. Инициирую плавное выключение..." << std::endl;
        stop_application = true;
    }
}

void run_prometheus_exporter(int port, std::shared_ptr<Registry> registry) {
    try {
        Exposer exposer{"0.0.0.0:" + std::to_string(port)};
        exposer.RegisterCollectable(registry);
        std::cout << "Prometheus exporter запущен на порту " << port << std::endl;

        while (!stop_application) {
            std::this_thread::sleep_for(std::chrono::seconds(1)); 
        }
        std::cout << "Prometheus exporter остановлен." << std::endl;
    } catch (const std::runtime_error& e) {
        std::cerr << "Ошибка запуска Prometheus exporter: " << e.what() << std::endl;
    }
}
bool isPrime(long long n) {
    if (n <= 1) return false;
    if (n <= 3) return true;
    if (n % 2 == 0 || n % 3 == 0) return false;

    for (long long i = 5; i * i <= n; i += 6) {
        if (n % i == 0 || n % (i + 2) == 0)
            return false;
    }
    return true;
}

void process_input(long long n,
                   Counter& checked_numbers_total,
                   Counter& prime_numbers_found_total,
                   Counter& invalid_input_total,
                   Counter& out_of_range_total) {

    checked_numbers_count++;
    checked_numbers_total.Increment();

    if (n < 1 || n > 2000000000) {
        std::cerr << "Error: Number is out of the valid range (1 - 2 billion)." << std::endl;
        out_of_range_count++;
        out_of_range_total.Increment();
        return;
    }

    if (isPrime(n)) {
        std::cout << n << " is a prime number." << std::endl;
        prime_numbers_found_count++;
        prime_numbers_found_total.Increment();
    }
    else {
        std::cout << n << " is not a prime number." << std::endl;
    }
}

int main() {
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);

    const int PROMETHEUS_PORT = 9090; 
    auto registry = std::make_shared<Registry>();

    auto& checked_numbers_total = Counter::Build()
        .Name("prime_checks_total")
        .Help("Total number of prime checks performed")
        .Register(*registry);

    auto& prime_numbers_found_total = Counter::Build()
        .Name("prime_numbers_found_total")
        .Help("Total number of prime numbers found")
        .Register(*registry);

    auto& invalid_input_total = Counter::Build()
        .Name("invalid_input_total")
        .Help("Total count of invalid inputs")
        .Register(*registry);

    auto& out_of_range_total = Counter::Build()
        .Name("out_of_range_input_total")
        .Help("Total count of inputs outside the valid range")
        .Register(*registry);


    bool interactive = isatty(fileno(stdin));

    std::thread exporter_thread(run_prometheus_exporter, PROMETHEUS_PORT, registry);

    if (!interactive) {
        std::string input_line;
        std::cin >> input_line;
        try {
            long long n = std::stoll(input_line); 
            process_input(n, checked_numbers_total, prime_numbers_found_total, invalid_input_total, out_of_range_total);
        } catch (const std::invalid_argument& e) {
            std::cerr << "Error: Input is not a valid number." << std::endl;
            invalid_input_count++;
            invalid_input_total.Increment();
        } catch (const std::out_of_range& e) {
            std::cerr << "Error: Number is out of the range of long long." << std::endl;
            invalid_input_count++; 
            invalid_input_total.Increment();
        }
        checked_numbers_total.Increment(checked_numbers_count.load());
        prime_numbers_found_total.Increment(prime_numbers_found_count.load());
        invalid_input_total.Increment(invalid_input_count.load());
        out_of_range_total.Increment(out_of_range_count.load());

    } else {
        std::cout << "Enter numbers to check (from 1 to 2,000,000,000)." << std::endl;
        std::cout << "Type 'quit' to exit." << std::endl;

        std::string input_line;
        while (!stop_application) {
            std::cout << "Enter number: ";
            std::cin >> input_line;

            if (input_line == "quit") {
                stop_application = true;
                break;
            }

            try {
                long long n = std::stoll(input_line);
                process_input(n, checked_numbers_total, prime_numbers_found_total, invalid_input_total, out_of_range_total);
            } catch (const std::invalid_argument& e) {
                std::cerr << "Error: Input is not a valid number." << std::endl;
                invalid_input_count++;
                invalid_input_total.Increment();
            } catch (const std::out_of_range& e) {
                std::cerr << "Error: Number is out of the range of long long." << std::endl;
                invalid_input_count++;
                invalid_input_total.Increment();
            }
            std::this_thread::sleep_for(std::chrono::milliseconds(50));
        }
    }

    if (exporter_thread.joinable()) {
        exporter_thread.join();
    }

    std::cout << "Prime Checker application stopped." << std::endl;
    return 0;
}