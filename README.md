# zless-preview.yazi

Plugin for [`yazi`](https://github.com/sxyazi/yazi) terminal file manager to preview compressed text files using `zless`.

To install, run:
``` bash
ya pkg add vmikk/zless-preview
```

and add to your `yazi.toml`:

``` toml
[plugin]
prepend_previewers = [
    { name = "*.txt.gz", run = "zless-preview"},
]
```

To scroll rows in the preview, use `J` and `K` keys (note the capital letters).

