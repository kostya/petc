#include <stdio.h>
#include <stdlib.h>
int main() {
    int *arr = (int *)malloc(10 * sizeof(int));
    ((int(*)[10])arr)[0][5] = 5;

    printf("%d\n", arr[5]);
    free(arr);
    return 0;
}
