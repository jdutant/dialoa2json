# dialoa2json

Export Dialoa journal metadata as JSON.

## Dependencies

Requires Pandoc for execution and Lua Code Combine to build the source.

## Description

Exports metadata of a Dialoa journal issue in JSON and other formats.

## Usage

Run on an issue master file:

    pandoc lua dialoa2json.lua master.md

In the imports field of the master file, filepaths starting with
`${.}` are interpreted as relative to the master file; other
relative paths are interpreted as relative to the present working
directory.

Run with `-h` or `--help` to get further details on available 
commands.