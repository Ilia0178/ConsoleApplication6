#include <iostream>
#include <cmath>
#include <limits>
#include <clocale>

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

int main() {
    long long n;

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
    }
    else {
        std::cout << n << " is not a prime number." << std::endl;
    }

    return 0;
}