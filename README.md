# unity-setup

An atomic GitHub action to download and install the Unity Editor for runners.

* If a valid installation is found, then installation is skipped.
* If a module is missing for a valid build target, then the module is installed.
* Outputs:
  * `UNITY_EDITOR_PATH` The path to the Unity Editor Installation
  * `UNITY_PROJECT PATH` The path to the Unity Project

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
      fail-fast: false
      matrix:
        runner: [ ubuntu-latest, windows-latest, macos-latest ]
    runs-on: ${{ matrix.runner }}

    steps:
      - uses: actions/checkout@v3

      - id: unity-setup
        uses: xrtk/unity-setup@v2
          with:
            modules: 'android ios' #Optional, overrides the default platform specific module installs.
            #version-file-path: '**/ProjectSettings/ProjectVersion.txt' # Optional

      - run: |
          echo "${{ env.UNITY_EDITOR_PATH }}"
          echo "${{ env.UNITY_PROJECT_PATH }}"
```
