void test_comparisons() {
    int a = 5, b = 10;
    
    printf("lt: %d\n", a < b);
    printf("le: %d\n", a <= b);
    printf("gt: %d\n", a > b);
    printf("ge: %d\n", a >= b);
    printf("eq: %d\n", a == b);
    printf("ne: %d\n", a != b);
}

int main() {
    test_comparisons();
    return 0;
}
