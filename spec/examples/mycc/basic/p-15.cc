void test_switch(int x) {
    switch (x) {
        case 1:
            printf("switch: one\n");
            break;
        case 2:
            printf("switch: two\n");
            break;
        case 3:
            printf("switch: three\n");
            break;
        default:
            printf("switch: default\n");
    }
}

void test_switch2(int x) {
    switch (x) {
        case 1:
        case 2:
        case 3:
            printf("switch: 1-3\n");
            break;
        default:
            printf("switch: other\n");
    }
}

int main() {
	test_switch(0);
    test_switch(1);
    test_switch(2);
    test_switch(3);
    test_switch(4);

    printf("---\n");

    test_switch2(0);
    test_switch2(1);
    test_switch2(2);
    test_switch2(3);
    test_switch2(4);
    
    return 0;
}
