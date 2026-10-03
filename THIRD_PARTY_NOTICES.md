# Third-party notices

MouseScrollFix itself is MIT licensed (see `LICENSE`). The build tooling in `scripts/`
contains a small amount of third-party code, credited here.

## ds_store (buddy allocator)

`scripts/dmg-layout.py` writes `.DS_Store` files directly, because Finder can no longer
have its layout set without either granting a script permission to control Finder or
crafting the file by hand. The buddy allocator in that script (the `Block` and
`Allocator` classes) is a trimmed copy of the implementation from **ds_store**:

- Project: https://github.com/al45tair/ds_store
- Author: Alastair Houghton
- Licence: MIT

```
Copyright (c) 2011-2020 Alastair Houghton

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

## Apple documentation and headers

Behaviour of the scroll event fields (`scrollPhase`, `momentumPhase`,
`isContinuous`), the event-tap lifecycle and the permission model is derived from
Apple's public documentation and the macOS SDK headers shipped with the toolchain.
No Apple source code is included in this repository.
