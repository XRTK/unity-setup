# unity-setup

An atomic GitHub action to download and install the Unity Editor for runners.

* If a valid installation is found, then installation is skipped.
* If a module is missing for a valid build target, then the module is installed.
* Outputs:
  * The Unity Editor Installation Path
  * The Unity Project Path

Part of the [Mixed Reality Toolkit (XRTK)](https://github.com/XRTK) open source project.

> This action does require the use of XRTK in your Unity project.

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

    outputs:
      editor-path: ${{ steps.unity-setup.outputs.editor-path }}
      project-path: ${{ steps.unity-setup.outputs.project-path }}

    steps:
      - uses: actions/checkout@v3

      - id: unity-setup
        uses: xrtk/unity-setup@v1
          with:
            modules: 'android ios'

        run: echo ${{ steps.unity-setup.outputs.editor-path }}
        run: echo ${{ steps.unity-setup.outputs.project-path }}
```
