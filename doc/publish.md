# Publishing to pub.dev

This guide provides step-by-step instructions on how to publish `listen_core` (or any Dart/Flutter package) to [pub.dev](https://pub.dev).

## 📋 Prerequisites

Before you begin, ensure you have the following:
1.  A **Google Account** to sign in to pub.dev.
2.  Verified ownership of the domain (optional, but recommended for professional publishers).
3.  A complete `pubspec.yaml` with:
    - `name`, `description`, and `version`.
    - `homepage` or `repository` URL.
    - `environment` (SDK constraints).

## 🛠 Preparation

### 1. License File
Ensure there is a `LICENSE` file in the root directory. Most open-source Flutter packages use the **MIT License**.

### 2. Documentation
Verify that `README.md` and `CHANGELOG.md` are up to date. Pub.dev uses these files to generate the package's landing page and version history.

### 3. Static Analysis
Run the analyzer to ensure there are no warnings or errors:
```bash
flutter analyze
```

## 🚀 Publishing Steps

### Step 1: Dry Run
Always perform a "dry run" first. This simulates the publishing process and checks for common issues without actually uploading anything.

```bash
flutter pub publish --dry-run
```

Review the output. If there are any "Suggestions" or "Errors", fix them before proceeding.

### Step 2: Formal Publishing
Once the dry run is successful, run the following command to publish:

```bash
flutter pub publish
```

### Step 3: Authentication
- The terminal will provide a **URL**.
- Open the URL in your browser and sign in with your Google Account.
- Grant permissions to the Pub client.
- Once authenticated, the upload will begin automatically.

## ⚠️ Important Notes

- **Irreversibility**: Once a version is published to pub.dev, it **cannot be unpublished**. You can only "discontinue" a package or upload a new version.
- **Version Management**: Follow [Semantic Versioning (SemVer)](https://semver.org/).
- **Score**: After publishing, check your "Pub Points" on the package page. Improve your score by following the suggestions provided by the automated analysis.

## 📂 Useful Commands Summary

| Task | Command |
| :--- | :--- |
| Check for issues | `flutter pub publish --dry-run` |
| Publish package | `flutter pub publish` |
| Get dependencies | `flutter pub get` |
| Upgrade dependencies | `flutter pub upgrade` |
