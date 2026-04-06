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
// #include <prometheus/gauge.h> // Если будете использовать Gauge

// Используем пространство имен prometheus
using namespace prometheus;

// --- Переменные для приложения ---
// Удалены: std::atomic<long long> checked_numbers_count = 0;
// Удалены: std::atomic<long long> prime_numbers_found_count = 0;
// Удалены: std::atomic<long long> invalid_input_count = 0;
// Удалены: std::atomic<long long> out_of_range_count = 0;
std::atomic<bool> stop_application = false;

// --- Обработчик сигналов ---
void signal_handler(int signal) {
    if (signal == SIGINT || signal == SIGTERM) {
        std::cout << "\nПолучен сигнал завершения. Инициирую плавное выключение..." << std::endl;
        stop_application = true;
    }
}

// --- Функция для экспортера метрик ---
void run_prometheus_exporter(int port, std::shared_ptr<Registry> registry) {
    try {
        // Экспозер слушает на всех интерфейсах ("0.0.0.0")
        Exposer exposer{"0.0.0.0:" + std::to_string(port)};
        // Регистрируем наш Registry в экспозере
        exposer.RegisterCollectable(registry);
        std::cout << "Prometheus exporter запущен на порту " << port << std::endl;

        // Ждем, пока не будет установлен флаг остановки
        while (!stop_application) {
            std::this_thread::sleep_for(std::chrono::seconds(1)); 
        }
        std::cout << "Prometheus exporter остановлен." << std::endl;
    } catch (const std::runtime_error& e) {
        std::cerr << "Ошибка запуска Prometheus exporter: " << e.what() << std::endl;
    }
}

// --- Функция проверки на простоту числа ---
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

// --- Функция обработки ввода ---
// Использует метрики Prometheus, которые были созданы в main
void process_input(long long n,
                   Counter& checked_numbers_total,
                   Counter& prime_numbers_found_total,
                   Counter& invalid_input_total,
                   Counter& out_of_range_total) {

    checked_numbers_total.Increment(); // Обновляем метрику общего числа проверок

    if (n < 1 || n > 2000000000) {
        std::cerr << "Error: Number is out of the valid range (1 - 2 billion)." << std::endl;
        out_of_range_total.Increment(); // Обновляем метрику ошибок диапазона
        return; // Возвращаемся, не проверяя на простоту
    }

    if (isPrime(n)) {
        std::cout << n << " is a prime number." << std::endl;
        prime_numbers_found_total.Increment(); // Обновляем метрику найденных простых чисел
    } else {
        std::cout << n << " is not a prime number." << std::endl;
    }
}

// --- Основная логика приложения ---
int main(int argc, char* argv[]) {
    // --- Настройка локали ---
    setlocale(LC_ALL, "C");

    // --- Обработчик сигналов ---
    std::signal(SIGINT, signal_handler);
    std::signal(SIGTERM, signal_handler);

    const int PROMETHEUS_PORT = 9090; 

    // --- Создание Prometheus Registry ---
    auto registry = std::make_shared<Registry>();

    // --- Создание и регистрация метрик ---
    // В зависимости от версии prometheus-cpp, синтаксис может отличаться.
    // Используем синтаксис addCounter, если у вас старая версия (v0.x)
    // Если используется более новая версия (v1.x+), лучше использовать AddMetricWithLabels.

    // Вариант для prometheus-cpp v0.x:
    auto& checked_numbers_total = registry->addCounter(
        "prime_checks_total",
        "Total number of prime checks performed"
    );

    auto& prime_numbers_found_total = registry->addCounter(
        "prime_numbers_found_total",
        "Total number of prime numbers found"
    );

    auto& invalid_input_total = registry->addCounter(
        "invalid_input_total",
        "Total count of invalid inputs"
    );

    auto& out_of_range_total = registry->addCounter(
        "out_of_range_input_total",
        "Total count of inputs outside the valid range"
    );

    // Вариант для prometheus-cpp v1.x+:
    /*
    auto& checked_numbers_total = registry->AddMetricWithLabels<Counter>(
        "prime_checks_total",
        "Total number of prime checks performed",
        {} // пустые метки
    );

    auto& prime_numbers_found_total = registry->AddMetricWithLabels<Counter>(
        "prime_numbers_found_total",
        "Total number of prime numbers found",
        {}
    );

    auto& invalid_input_total = registry->AddMetricWithLabels<Counter>(
        "invalid_input_total",
        "Total count of invalid inputs",
        {}
    );

    auto& out_of_range_total = registry->AddMetricWithLabels<Counter>(
        "out_of_range_input_total",
        "Total count of inputs outside the valid range",
        {}
    );
    */


    // --- Определение интерактивного режима ---
    bool interactive = isatty(fileno(stdin)); // Проверяем, является ли stdin терминалом

    // --- Запуск экспортера метрик в отдельном потоке ---
    std::thread exporter_thread(run_prometheus_exporter, PROMETHEUS_PORT, registry);

    // --- Основной цикл обработки ввода ---
    if (interactive) {
        std::cout << "Enter numbers to check (from 1 to 2,000,000,000)." << std::endl;
        std::cout << "Type 'quit' to exit." << std::endl;

        std::string input_line;
        while (!stop_application) {
            std::cout << "Enter number: ";
            // Используем getline для корректного чтения всей строки
            if (!std::getline(std::cin, input_line)) {
                // Если чтение из cin не удалось (например, конец файла при пайпинге)
                stop_application = true; 
                break;
            }

            if (input_line == "quit") {
                stop_application = true;
                break;
            }

            try {
                long long n = std::stoll(input_line);
                // process_input уже инкрементирует метрики Prometheus
                process_input(n, checked_numbers_total, prime_numbers_found_total, invalid_input_total, out_of_range_total);
            } catch (const std::invalid_argument& e) {
                std::cerr << "Error: Input is not a valid number." << std::endl;
                invalid_input_total.Increment(); // Только метрика Prometheus
            } catch (const std::out_of_range& e) {
                std::cerr << "Error: Number is out of the range of long long." << std::endl;
                invalid_input_total.Increment(); // Только метрика Prometheus
            }
            // Небольшая пауза, чтобы не нагружать CPU при интерактивном вводе
            std::this_thread::sleep_for(std::chrono::milliseconds(50));
        }
    } else { // Неинтерактивный режим (пайп)
        std::string input_line;
        // Читаем построчно, пока есть ввод
        while (std::getline(std::cin, input_line)) {
            if (input_line.empty()) continue; // Пропускаем пустые строки
            
            try {
                long long n = std::stoll(input_line);
                // process_input уже инкрементирует метрики Prometheus
                process_input(n, checked_numbers_total, prime_numbers_found_total, invalid_input_total, out_of_range_total);
            } catch (const std::invalid_argument& e) {
                std::cerr << "Error: Input is not a valid number." << std::endl;
                invalid_input_total.Increment(); // Только метрика Prometheus
            } catch (const std::out_of_range& e) {
                std::cerr << "Error: Number is out of the range of long long." << std::endl;
                invalid_input_total.Increment(); // Только метрика Prometheus
            }
        }
        // После завершения чтения из пайпа, устанавливаем флаг остановки
        stop_application = true; 
    }

    // --- Ожидание завершения потока экспортера ---
    if (exporter_thread.joinable()) {
        exporter_thread.join();
    }

    std::cout << "Prime Checker application stopped." << std::endl;
    return 0;
}