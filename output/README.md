# nushell

A new type of shell — pipelines operate on structured data instead of raw
text, with a modern, typed language and first-class support for JSON, CSV,
SQLite and more.

This package ships `nu` (registered in /etc/shells, so `chsh -s /usr/bin/nu`
works out of the box) and the official plugins: `nu_plugin_formats`,
`nu_plugin_gstat`, `nu_plugin_inc`, `nu_plugin_polars`, `nu_plugin_query`.
Register a plugin from inside nu, e.g.: `plugin add /usr/bin/nu_plugin_query`.

- Upstream: https://github.com/nushell/nushell
- Documentation: https://www.nushell.sh/book/
- Packaging: https://github.com/dariogriffo/nushell-debian
- Repository: https://deb.griffo.io
