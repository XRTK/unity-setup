# unity-setup

An atomic GitHub action to download and install the Unity Editor for runners.

* If a valid installation is found, then installation is skipped.
* If a module is missing for a valid build target, then the module is installed.
* Outputs:
  * `UNITY_EDITOR_PATH` The path to the Unity Editor Installation.
  * `UNITY_PROJECT PATH` The path to the Unity Project.
  * `UNITY_EDITOR_VERSION` The version of the Unity Editor that was installed.

Part of the [Mixed Reality Toolkit (XRTK)](https://github.com/XRTK) open source project.

> This action does not require the use of XRTK in your Unity project.

## Related Github Actions

* [xrtk/activate-unity-license](https://github.com/XRTK/activate-unity-license)
* [xrtk/unity-action](https://github.com/XRTK/unity-action)
* [xrtk/unity-build](https://github.com/XRTK/unity-build) ***(Requires XRTK plugin in Unity Project)***

## How to use

```yaml
jobs:
  setup-unity:
  strategy:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        include:
          - os: ubuntu-latest
            build-targets: 'StandaloneLinux64 Android iOS'
          - os: windows-latest
            build-targets: 'StandaloneWindows64 Android iOS'
          - os: macos-latest
            build-targets: 'StandaloneOSX Android iOS'

    steps:
      - uses: actions/checkout@v4

      - id: unity-setup
        uses: xrtk/unity-setup@v7
        with:
          build-targets: ${{ matrix.build-targets }} # Optional, specify the build targets to install
          version-file-path: 'ProjectSettings/ProjectVersion.txt' # Optional, specify a path to the unity project version text file
          # architecture: 'arm64' # Optional, specify the architecture to install (x86_64 or arm64)

      - run: |
          echo "${{ env.UNITY_EDITOR_PATH }}"
          echo "${{ env.UNITY_PROJECT_PATH }}"
```
