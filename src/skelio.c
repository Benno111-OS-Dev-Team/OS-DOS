#include "boot.h"

enum {
    DEVICE_ATTR_CHAR = 0x8000u,
    DEVICE_ATTR_CON_IN = 0x0001u,
    DEVICE_ATTR_CON_OUT = 0x0002u,
    DEVICE_ATTR_NUL = 0x0004u,
    DEVICE_ATTR_CLOCK = 0x0008u
};

static const BootDevice kDiskDevice = {
    "DSK",
    0x2000u,
    0,
    0,
    NULL
};

static const BootDevice kCom1Device = {
    "COM1",
    DEVICE_ATTR_CHAR,
    0,
    0,
    &kDiskDevice
};

static const BootDevice kClockDevice = {
    "CLOCK",
    DEVICE_ATTR_CHAR | DEVICE_ATTR_CLOCK,
    0,
    0,
    &kCom1Device
};

static const BootDevice kPrnDevice = {
    "PRN",
    DEVICE_ATTR_CHAR | DEVICE_ATTR_CON_OUT,
    0,
    0,
    &kClockDevice
};

static const BootDevice kAuxDevice = {
    "AUX",
    DEVICE_ATTR_CHAR,
    0,
    0,
    &kPrnDevice
};

static const BootDevice kConDevice = {
    "CON",
    DEVICE_ATTR_CHAR | DEVICE_ATTR_CON_IN | DEVICE_ATTR_CON_OUT,
    0,
    0,
    &kAuxDevice
};

void boot_state_init(BootState *state) {
    if (!state) {
        return;
    }

    state->bios_handoff_size = 8192u;
    state->bios_handoff_paragraphs = 0x200u;
    state->bios_segment = 0x00C0u;
    state->memory_size_paragraphs = 0x4000u;
    state->default_drive = 0u;
    state->buffers = 2u;
    state->current_dos_location = state->bios_segment;
    state->final_dos_location = state->bios_segment + state->bios_handoff_paragraphs;
    state->device_list = &kConDevice;
}

void skelio_bootstrap(BootState *state) {
    boot_state_init(state);
}
