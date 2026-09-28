#include <stdbool.h>
#include <windows.h>
#include <wchar.h>

static bool has_argument(int argc, wchar_t **argv, const wchar_t *needle) {
    for (int index = 1; index < argc; ++index) {
        if (wcscmp(argv[index], needle) == 0) return true;
    }
    return false;
}

static bool append_path(wchar_t *destination, size_t capacity, const wchar_t *directory, const wchar_t *name) {
    int written = _snwprintf(destination, capacity, L"%ls\\%ls", directory, name);
    return written >= 0 && (size_t)written < capacity;
}

int wmain(int argc, wchar_t **argv) {
    enum { PATH_CAPACITY = 32768 };
    wchar_t package_executable[PATH_CAPACITY];
    wchar_t package_real_executable[PATH_CAPACITY];
    wchar_t package_pck[PATH_CAPACITY];
    wchar_t temp_directory[PATH_CAPACITY];
    wchar_t temp_workspace[PATH_CAPACITY];
    wchar_t executable[PATH_CAPACITY];
    wchar_t real_pck[PATH_CAPACITY];
    wchar_t command_line[PATH_CAPACITY];
    wchar_t *separator;
    PROCESS_INFORMATION process = {0};
    STARTUPINFOW startup = {.cb = sizeof(startup)};
    DWORD exit_code = 1;
    DWORD length;
    DWORD temp_length;
    bool workspace_created = false;
    int used;
    int result = 1;

    length = GetModuleFileNameW(NULL, package_executable, PATH_CAPACITY);
    if (length == 0 || length >= PATH_CAPACITY) return 1;
    wcscpy(package_real_executable, package_executable);
    separator = wcsrchr(package_real_executable, L'\\');
    if (separator == NULL) separator = wcsrchr(package_real_executable, L'/');
    if (separator == NULL) return 1;
    wcscpy(separator + 1, L"modus-real.exe");

    wcscpy(package_pck, package_executable);
    separator = wcsrchr(package_pck, L'\\');
    if (separator == NULL) separator = wcsrchr(package_pck, L'/');
    if (separator == NULL) return 1;
    wcscpy(separator + 1, L"modus.pck");

    DWORD package_pck_attributes = GetFileAttributesW(package_pck);
    if (package_pck_attributes == INVALID_FILE_ATTRIBUTES ||
        (package_pck_attributes & FILE_ATTRIBUTE_DIRECTORY) != 0) {
        return 1;
    }

    temp_length = GetTempPathW(PATH_CAPACITY, temp_directory);
    if (temp_length == 0 || temp_length >= PATH_CAPACITY ||
        GetTempFileNameW(temp_directory, L"MOD", 0, temp_workspace) == 0) {
        return 1;
    }
    if (DeleteFileW(temp_workspace) == 0 || CreateDirectoryW(temp_workspace, NULL) == 0) {
        return 1;
    }
    workspace_created = true;
    if (!append_path(executable, PATH_CAPACITY, temp_workspace, L"modus-real.exe") ||
        !append_path(real_pck, PATH_CAPACITY, temp_workspace, L"modus-real.pck") ||
        !CopyFileW(package_real_executable, executable, FALSE) ||
        !CopyFileW(package_pck, real_pck, FALSE)) {
        goto cleanup;
    }

    used = _snwprintf(
        command_line,
        PATH_CAPACITY,
        L"\"%ls\"",
        executable
    );
    if (used < 0 || (size_t)used >= PATH_CAPACITY) goto cleanup;

    bool package_smoke = has_argument(argc, argv, L"--package-smoke");
    if (package_smoke && !has_argument(argc, argv, L"--headless")) {
        int added = _snwprintf(
            command_line + used,
            PATH_CAPACITY - (size_t)used,
            L" --headless"
        );
        if (added < 0 || (size_t)(used + added) >= PATH_CAPACITY) goto cleanup;
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
                PATH_CAPACITY - (size_t)used,
                L" \"%ls\"",
                smoke_arguments[index]
            );
            if (added < 0 || (size_t)(used + added) >= PATH_CAPACITY) goto cleanup;
            used += added;
        }
    }
    for (int index = 1; index < argc; ++index) {
        int added = _snwprintf(
            command_line + used,
            PATH_CAPACITY - (size_t)used,
            L" \"%ls\"",
            argv[index]
        );
        if (added < 0 || (size_t)(used + added) >= PATH_CAPACITY) goto cleanup;
        used += added;
    }

    if (!CreateProcessW(
            executable,
            command_line,
            NULL,
            NULL,
            FALSE,
            CREATE_NO_WINDOW,
            NULL,
            temp_workspace,
            &startup,
            &process)) {
        goto cleanup;
    }
    WaitForSingleObject(process.hProcess, INFINITE);
    if (GetExitCodeProcess(process.hProcess, &exit_code) != 0) {
        result = (int)exit_code;
    }
    CloseHandle(process.hThread);
    CloseHandle(process.hProcess);
    process.hThread = NULL;
    process.hProcess = NULL;

cleanup:
    if (process.hThread != NULL) CloseHandle(process.hThread);
    if (process.hProcess != NULL) CloseHandle(process.hProcess);
    if (workspace_created) {
        DeleteFileW(real_pck);
        DeleteFileW(executable);
        RemoveDirectoryW(temp_workspace);
    }
    return result;
}
