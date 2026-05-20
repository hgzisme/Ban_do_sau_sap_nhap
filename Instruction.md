# Launch Instructions for "Bản đồ hành chính Việt Nam sau sáp nhập"

This is a Flutter desktop application. To run this project locally, you will need to install the Flutter SDK and the necessary build tools for your operating system.

## Prerequisites

### 1. Flutter SDK
Download and install the Flutter SDK from the official website:
[Flutter Installation Guide](https://docs.flutter.dev/get-started/install)

Make sure you add the `flutter/bin` directory to your system's PATH.

### 2. Desktop Build Tools

Depending on your operating system, you will need specific build tools to run the desktop application:

#### For Windows:
You must install **Visual Studio 2022** (not Visual Studio Code) with the "**Desktop development with C++**" workload.
- Download Visual Studio: [Visual Studio Downloads](https://visualstudio.microsoft.com/downloads/)
- During installation, make sure to check the "Desktop development with C++" workload.

#### For macOS:
You must install **Xcode**.
- Download Xcode from the Mac App Store.
- After installation, run `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer` and `sudo xcodebuild -runFirstLaunch`.
- You also need to install CocoaPods: `sudo gem install cocoapods`.

#### For Linux:
You will need tools like `clang`, `cmake`, `ninja-build`, `pkg-config`, and `libgtk-3-dev`.
- On Ubuntu/Debian, you can install them using:
  ```bash
  sudo apt-get install clang cmake git ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev
  ```

### 3. Verify Installation
After installing Flutter and the build tools, open your terminal (or Command Prompt/PowerShell on Windows) and run:
```bash
flutter doctor
```
Ensure there are no issues related to your target desktop platform.

---

## How to Launch the Project

Once the prerequisites are met, follow these steps to run the application:

**Note**: Turn on Developer Mode in Window Settings -> Privacy & Security -> Developer Mode, then restart the computer


1. **Open the project** in your preferred IDE (e.g., Visual Studio Code or Android Studio) or navigate to the project directory in your terminal:
   ```bash
   cd path/to/Ban_do_sau_sap_nhap
   ```

2. **Fetch dependencies**:
   Run the following command to download all required packages defined in `pubspec.yaml` (such as `syncfusion_flutter_maps` and `google_fonts`):
   ```bash
   flutter pub get
   ```

3. **Run the application**:
   To launch the app on your desktop, use the `flutter run` command specifying your desktop platform:

   *For Windows:*
   ```bash
   flutter run -d windows
   ```

   *For macOS:*
   ```bash
   flutter run -d macos
   ```

   *For Linux:*
   ```bash
   flutter run -d linux
   ```

Alternatively, if you are using Visual Studio Code or Android Studio, you can simply select your desktop device (e.g., "Windows (desktop)") from the device dropdown and click the "Run" or "Debug" button.
