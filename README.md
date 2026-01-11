# Artisanal Reskins: Sprite Utils

A set of standalone icon and sprite utilities developed to support the Artisanal Reskins ecosystem,
repackaged for general use.


## Usage Guidance

Most functions are designed to accept whole prototypes for retrieving/manipulating icons. However,
often related functions will accept a `name` and `type_name` instead.


## Concepts

### `icon_datum`

An "icon datum" is used throughout this library to refer to a single layer of an icon: [`IconData`](https://lua-api.factorio.com/latest/types/IconData.html)

### `icon_data`

An "icon_data" is used to refer to an *array* of "icon_datums": `IconData[]`.