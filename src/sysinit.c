#include "boot.h"

static void default_log(void *user_data, const char *message) {
    (void)user_data;
    (void)message;
}

static void emit_log(BootLogFn log_fn, void *user_data, const char *message) {
    if (log_fn) {
        log_fn(user_data, message);
        return;
    }

    default_log(user_data, message);
}

static int scan_memory(BootState *state) {
    if (!state) {
        return -1;
    }

    if (state->memory_size_paragraphs == 0) {
        state->memory_size_paragraphs = 0x4000u;
    }

    return 0;
}

static int relocate_dos(BootState *state) {
    if (!state) {
        return -1;
    }

    state->current_dos_location = state->bios_segment;
    state->final_dos_location = state->bios_segment + state->bios_handoff_paragraphs;
    return 0;
}

int sysinit_run(BootState *state, BootLogFn log_fn, void *user_data) {
    size_t message_count = 0;
    const char *const *messages = sysinit_messages(&message_count);

    if (!state) {
        return -1;
    }

    if (message_count > 0) {
        emit_log(log_fn, user_data, messages[0]);
    }

    if (scan_memory(state) != 0) {
        return -1;
    }

    if (message_count > 3) {
        emit_log(log_fn, user_data, messages[3]);
    }

    if (relocate_dos(state) != 0) {
        return -1;
    }

    if (message_count > 4) {
        emit_log(log_fn, user_data, messages[4]);
    }

    if (message_count > 5) {
        emit_log(log_fn, user_data, messages[5]);
    }

    if (message_count > 6) {
        emit_log(log_fn, user_data, messages[6]);
    }

    if (message_count > 7) {
        emit_log(log_fn, user_data, messages[7]);
    }

    if (message_count > 8) {
        emit_log(log_fn, user_data, messages[8]);
    }

    if (message_count > 9) {
        emit_log(log_fn, user_data, messages[9]);
    }

    if (message_count > 10) {
        emit_log(log_fn, user_data, messages[10]);
    }

    if (message_count > 11) {
        emit_log(log_fn, user_data, messages[11]);
    }

    if (message_count > 12) {
        emit_log(log_fn, user_data, messages[12]);
    }

    if (message_count > 13) {
        emit_log(log_fn, user_data, messages[13]);
    }

    return 0;
}
