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
    wchar_t real_pck[32768];
    wchar_t package_pck[32768];
    bool generated_pck = false;
    PROCESS_INFORMATION process = {0};
    DWORD exit_code = 1;
    int result = 1;

    DWORD length = GetModuleFileNameW(NULL, executable, sizeof(executable) / sizeof(executable[0]));
    if (length == 0 || length >= sizeof(executable) / sizeof(executable[0])) return 1;
    wchar_t *separator = wcsrchr(executable, L'\\');
    if (separator == NULL) separator = wcsrchr(executable, L'/');
    if (separator == NULL) return 1;
    wcscpy(separator + 1, L"modus-real.exe");

    wcscpy(real_pck, executable);
    separator = wcsrchr(real_pck, L'\\');
    if (separator == NULL) separator = wcsrchr(real_pck, L'/');
    if (separator == NULL) return 1;
    wcscpy(separator + 1, L"modus-real.pck");
    wcscpy(package_pck, executable);
    separator = wcsrchr(package_pck, L'\\');
    if (separator == NULL) separator = wcsrchr(package_pck, L'/');
    if (separator == NULL) return 1;
    wcscpy(separator + 1, L"modus.pck");

    DWORD real_pck_attributes = GetFileAttributesW(real_pck);
    if (real_pck_attributes == INVALID_FILE_ATTRIBUTES) {
        DWORD package_pck_attributes = GetFileAttributesW(package_pck);
        if (package_pck_attributes == INVALID_FILE_ATTRIBUTES ||
            (package_pck_attributes & FILE_ATTRIBUTE_DIRECTORY) != 0) {
            return 1;
        }
        if (CreateHardLinkW(real_pck, package_pck, NULL) == 0 &&
            CopyFileW(package_pck, real_pck, FALSE) == 0) {
            return 1;
        }
        generated_pck = true;
    } else if ((real_pck_attributes & FILE_ATTRIBUTE_DIRECTORY) != 0) {
        return 1;
    }

    wchar_t command_line[32768];
    int used = _snwprintf(
        command_line,
        sizeof(command_line) / sizeof(command_line[0]),
        L"\"%ls\"",
        executable
    );
    if (used < 0 || (size_t)used >= sizeof(command_line) / sizeof(command_line[0])) goto cleanup;

    bool package_smoke = has_argument(argc, argv, L"--package-smoke");
    if (package_smoke && !has_argument(argc, argv, L"--headless")) {
        int added = _snwprintf(
            command_line + used,
            sizeof(command_line) / sizeof(command_line[0]) - (size_t)used,
            L" --headless"
        );
        if (added < 0 || (size_t)(used + added) >= sizeof(command_line) / sizeof(command_line[0])) goto cleanup;
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
            if (added < 0 || (size_t)(used + added) >= sizeof(command_line) / sizeof(command_line[0])) goto cleanup;
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
        if (added < 0 || (size_t)(used + added) >= sizeof(command_line) / sizeof(command_line[0])) goto cleanup;
        used += added;
    }

    STARTUPINFOW startup = {.cb = sizeof(startup)};
    if (!CreateProcessW(executable, command_line, NULL, NULL, FALSE, CREATE_NO_WINDOW, NULL, NULL, &startup, &process)) goto cleanup;
    WaitForSingleObject(process.hProcess, INFINITE);
    GetExitCodeProcess(process.hProcess, &exit_code);
    CloseHandle(process.hThread);
    CloseHandle(process.hProcess);
    result = (int)exit_code;

cleanup:
    if (generated_pck) DeleteFileW(real_pck);
    return result;
}
