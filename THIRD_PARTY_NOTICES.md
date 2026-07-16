# Third Party Notices

mimic incorporates source code from the following third-party project.

---

## cc-mek-scada

- **Project:** cc-mek-scada
- **Author:** Mikayla Fischler
- **Source:** https://github.com/MikaylaFischler/cc-mek-scada
- **License:** MIT
- **Vendored version:** graphics module `v2.4.11` (from `graphics/core.lua` → `core.version`)
- **Vendored on:** 2026-07-16

### Files vendored

Copied at their original paths, so that upstream fixes remain a straightforward merge:

- `graphics/` — the complete graphics module (engine + elements + themes)
- `scada-common/util.lua`
- `scada-common/tcd.lua`
- `scada-common/log.lua`
- `scada-common/psil.lua`
- `initenv.lua`

### Modifications made

The vendored code is otherwise **unmodified**. The only changes:

1. **Deleted** `graphics/elements/indicators/CoreMap.lua` — renders a Mekanism fission reactor core grid; specific to the original project's domain.
2. **Deleted** `graphics/elements/indicators/RadIndicator.lua` — displays radiation readings; specific to the original project's domain. It was the only consumer of `scada-common/types.lua`, which is therefore not vendored.
3. **Removed** `util.turbine_rotation()` from `scada-common/util.lua` — computed Mekanism turbine rotation. It was the only consumer of `scada-common/constants.lua`, which is therefore not vendored. Its `require` of that module was removed with it.

No other lines of the vendored code have been altered.

### Note on theme naming

`graphics/themes.lua` includes a front panel theme named `basalt`. This name originates
from the upstream project (it refers to the Minecraft block) and is **unrelated** to the
[Basalt](https://basalt.madefor.cc/) UI framework for CC:Tweaked.

---

### MIT License

```
MIT License

Copyright 2022 - 2026 Mikayla Fischler

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
