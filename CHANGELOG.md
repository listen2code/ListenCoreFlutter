## 0.0.4

* **Documentation**:
    * Added comprehensive multilingual README with English, Chinese, and Japanese support
    * Expanded usage examples from 3 to 10 sections covering all core features
    * Added detailed "Apps Using ListenCore" section featuring ListenPortfolioFlutter

* **API Documentation**:
    * Added comprehensive DartDoc comments to BaseViewModel, ViewModelMixin, and PageLifecycle
    * Documented ApiClient and IApiInterceptorDelegate for authentication and tracing
    * Added technical documentation for NetworkConfig, HttpCode, and logging infrastructure

* **Architecture Enhancements**:
    * Refined BaseViewModel structure with clearer separation of concerns
    * Improved ViewModelMixin with better event subscription and request cancellation management

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
