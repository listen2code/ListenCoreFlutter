## 0.0.3

* **Documentation & Architecture**:
    * Merged `core-architecture.md` into `README.md` for a unified technical overview.
    * Added a comprehensive publishing guide (`docs/publish.md`) for `pub.dev`.
* **Tooling Improvements**:
    * Optimized `LocalMockServer` path resolution logic to automatically match JSON files based on HTTP methods and versioned URL paths (e.g., `[DELETE] /v1/user` -> `json/v1/delete/user.json`).
* **Dependency Management**:
    * Resolved a version solving conflict by unifying `listen_core` as a path dependency across all local modules (`ListenUiKit` and main app).

## 0.0.2

* Fixed `dart analyze` warnings:
    * Removed unused variable in `LocalMockServer`.
    * Removed deprecated `encryptedSharedPreferences` parameter in `SecureStorageUtil`.
    * Fixed HTML conflict in `SpUtil` doc comments.
* Updated `pubspec.yaml` with repository information.
* Added `device_info_plus` and `package_info_plus` dependencies.
* Refined `README.md` and updated `LICENSE`.

## 0.0.1

* Initial release of Listen Core.
