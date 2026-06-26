void test_control_flow() {
    int x = 10;
    if (x > 5) {
        printf("if: x > 5\n");
    } else {
        printf("if: x <= 5\n");
    }
    
    if (x > 0) {
        if (x < 20) {
            printf("nested: 0 < x < 20\n");
        }
    }
    
    int i = 0;
    while (i < 3) {
        printf("while: %d\n", i);
        i = i + 1;
    }
    
    for (int j = 0; j < 3; j = j + 1) {
        printf("for: %d\n", j);
    }
    
    int k = 0;
    while (1) {
        k = k + 1;
        if (k >= 5) {
            break;
        }
        printf("break test: %d\n", k);
    }
}

int main() {
	test_control_flow();
    
    return 0;
}
