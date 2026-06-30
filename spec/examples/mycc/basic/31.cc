typedef enum {
    RED = 0,
    GREEN = 1,
    BLUE,
} Color;

void test_color(Color c) {
    switch (c) {
        case RED:   printf("red\n"); break;
        case GREEN: printf("green\n"); break;
        case BLUE:  printf("blue\n"); break;
        default:    printf("unknown\n");
    }
}

int main() {
    test_color(RED);
    test_color(GREEN);
    test_color(BLUE);
    return 0;
}