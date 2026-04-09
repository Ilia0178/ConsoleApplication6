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

std::cout << "Enter an integer to check (from 1 to 2,000,000,000): ";

if (!(std::cin >> n)) {
    std::cerr << "Error: Input is not a valid number." << std::endl;
    return 1;
}

if (n < 1 || n > 2000000000) {
    std::cerr << "Error: Number is out of the valid range (1 - 2 billion)." << std::endl;
    return 1;
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

    // --- Исправленный способ получения Counter из Family ---
    auto& checked_numbers_family = prometheus::BuildCounter()
        .Name("prime_checks_total")
        .Help("Total number of prime checks performed")
        .Register(*registry);
    auto& checked_numbers_total = checked_numbers_family.Add({}); // Add({}) создает Counter без меток

    auto& prime_numbers_found_family = prometheus::BuildCounter()
        .Name("prime_numbers_found_total")
        .Help("Total number of prime numbers found")
        .Register(*registry);
    auto& prime_numbers_found_total = prime_numbers_found_family.Add({});

    auto& invalid_input_family = prometheus::BuildCounter()
        .Name("invalid_input_total")
        .Help("Total count of invalid inputs")
        .Register(*registry);
    auto& invalid_input_total = invalid_input_family.Add({});

    auto& out_of_range_family = prometheus::BuildCounter()
        .Name("out_of_range_input_total")
        .Help("Total count of inputs outside the valid range")
        .Register(*registry);
    auto& out_of_range_total = out_of_range_family.Add({});
    // --- Теперь checked_numbers_total и другие имеют тип Counter& ---

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
                process_input(n, checked_numbers_total, prime_numbers_found_total, out_of_range_total);
            } catch (...) {
                invalid_input_total.Increment(); // Инкрементируем invalid_input_total напрямую
                std::cerr << "Invalid input." << std::endl;
            }
            std::this_thread::sleep_for(std::chrono::milliseconds(50));
        }
    } else { // Неинтерактивный режим
        std::string input_line;
        while (std::getline(std::cin, input_line)) {
            if (input_line.empty()) continue;
            try {
                long long n = std::stoll(input_line);
                process_input(n, checked_numbers_total, prime_numbers_found_total, out_of_range_total);
            } catch (...) {
                invalid_input_total.Increment(); // Инкрементируем invalid_input_total напрямую
            }
        }
    }

    stop_application = true;
    if (exporter_thread.joinable()) exporter_thread.join();
    return 0;
}