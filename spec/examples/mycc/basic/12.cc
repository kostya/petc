int fib(int n) {
    if (n <= 1) return n;
    return fib(n-1) + fib(n-2);
}

int fact(int n) {
    if (n <= 1) return 1;
    return n * fact(n-1);
}


int main() {
    printf("fib(10): %d\n", fib(10));
    printf("fact(5): %d\n", fact(5));
    
    return 0;
}