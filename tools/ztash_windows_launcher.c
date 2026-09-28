#include <stdbool.h>
#include <windows.h>
#include <wchar.h>

static bool has_argument(int argc, wchar_t **argv, const wchar_t *needle) {
    for (int index = 1; index < argc; ++index) {
        if (wcscmp(argv[index], needle) == 0) return true;
    }
    return false;
}

int wmain(int argc, wchar_t **argv) {
    wchar_t executable[32768];
    DWORD length = GetModuleFileNameW(NULL, executable, sizeof(executable) / sizeof(executable[0]));
    if (length == 0 || length >= sizeof(executable) / sizeof(executable[0])) return 1;
    wchar_t *separator = wcsrchr(executable, L'\\');
    if (separator == NULL) separator = wcsrchr(executable, L'/');
    if (separator == NULL) return 1;
    wcscpy(separator + 1, L"modus-real.exe");

    wchar_t command_line[32768];
    int used = _snwprintf(
        command_line,
        sizeof(command_line) / sizeof(command_line[0]),
        L"\"%ls\"",
        executable
    );
    if (used < 0 || (size_t)used >= sizeof(command_line) / sizeof(command_line[0])) return 1;

    bool package_smoke = has_argument(argc, argv, L"--package-smoke");
    if (package_smoke && !has_argument(argc, argv, L"--headless")) {
        int added = _snwprintf(
            command_line + used,
            sizeof(command_line) / sizeof(command_line[0]) - (size_t)used,
            L" --headless"
        );
        if (added < 0 || (size_t)(used + added) >= sizeof(command_line) / sizeof(command_line[0])) return 1;
        used += added;
    }
    if (package_smoke) {
        const wchar_t *smoke_arguments[] = {
            L"--audio-driver", L"Dummy",
            L"--rendering-method", L"gl_compatibility",
        };
        for (size_t index = 0; index < sizeof(smoke_arguments) / sizeof(smoke_arguments[0]); ++index) {
            int added = _snwprintf(
                command_line + used,
                sizeof(command_line) / sizeof(command_line[0]) - (size_t)used,
                L" \"%ls\"",
                smoke_arguments[index]
            );
            if (added < 0 || (size_t)(used + added) >= sizeof(command_line) / sizeof(command_line[0])) return 1;
            used += added;
        }
    }
    for (int index = 1; index < argc; ++index) {
        int added = _snwprintf(
            command_line + used,
            sizeof(command_line) / sizeof(command_line[0]) - (size_t)used,
            L" \"%ls\"",
            argv[index]
        );
        if (added < 0 || (size_t)(used + added) >= sizeof(command_line) / sizeof(command_line[0])) return 1;
        used += added;
    }

    STARTUPINFOW startup = {.cb = sizeof(startup)};
    PROCESS_INFORMATION process;
    if (!CreateProcessW(executable, command_line, NULL, NULL, FALSE, CREATE_NO_WINDOW, NULL, NULL, &startup, &process)) return 1;
    WaitForSingleObject(process.hProcess, INFINITE);
    DWORD exit_code = 1;
    GetExitCodeProcess(process.hProcess, &exit_code);
    CloseHandle(process.hThread);
    CloseHandle(process.hProcess);
    return (int)exit_code;
}
