#include <dos.h>

static void clear_screen(void) {
    unsigned char far *video = (unsigned char far *)MK_FP(0xB800, 0);
    int i;

    for (i = 0; i < 80 * 25; ++i) {
        video[i * 2] = ' ';
        video[i * 2 + 1] = 0x07;
    }
}

static void write_message(const char *msg) {
    unsigned char far *video = (unsigned char far *)MK_FP(0xB800, 0);
    int i;

    for (i = 0; msg[i] != '\0'; ++i) {
        video[i * 2] = (unsigned char)msg[i];
        video[i * 2 + 1] = 0x0F;
    }
}

void main(void) {
    clear_screen();
    write_message("OS-DOS boot kernel ready");

    for (;;) {
        _asm { hlt }
    }
}
