void test_bitwise() {
    int a = 0b1010, b = 0b1100;  // 10, 12
    
    printf("and: %d\n", a & b);   // 8
    printf("or: %d\n", a | b);    // 14
    printf("xor: %d\n", a ^ b);   // 6
    printf("not: %d\n", ~a);      // -11
    printf("shl: %d\n", a << 2);  // 40
    printf("shr: %d\n", a >> 1);  // 5
}

int main() {
    test_bitwise();
    return 0;
}
