# zless-preview.yazi

`zless` previewer for `yazi`.

To install, run:
``` bash
ya pack -a vmikk/zless-preview
```

and add to your `yazi.toml`:

``` toml
[plugin]
prepend_previewers = [
    { name = "*.txt.gz", run = "zless-preview"},
]
```

