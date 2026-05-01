#ifndef OS_DOS_BOOT_H
#define OS_DOS_BOOT_H

#include <stddef.h>

typedef struct BootDevice BootDevice;

typedef struct BootState {
    unsigned bios_handoff_size;
    unsigned bios_handoff_paragraphs;
    unsigned bios_segment;
    unsigned memory_size_paragraphs;
    unsigned default_drive;
    unsigned buffers;
    unsigned current_dos_location;
    unsigned final_dos_location;
    const BootDevice *device_list;
} BootState;

struct BootDevice {
    const char *name;
    unsigned attributes;
    unsigned strategy_id;
    unsigned interrupt_id;
    const BootDevice *next;
};

typedef void (*BootLogFn)(void *user_data, const char *message);

void boot_state_init(BootState *state);
void skelio_bootstrap(BootState *state);
int sysinit_run(BootState *state, BootLogFn log_fn, void *user_data);
int osdos_boot(BootLogFn log_fn, void *user_data);

const char *const *sysinit_messages(size_t *count);
const char *const *sysinit_errors(size_t *count);

#endif
